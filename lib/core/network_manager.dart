import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

enum DeviceRole { host, canvasOnly, topBarOnly, bottomBarOnly }

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  bool isHost = true;
  DeviceRole currentRole = DeviceRole.host;

  HttpServer? _server;
  final List<WebSocket> _connectedClients = [];
  final Map<WebSocket, DeviceRole> clientRoles = {};

  WebSocket? _clientConnection;

  RawDatagramSocket? _udpResponderSocket;
  RawDatagramSocket? _udpDiscoverySocket;

  Function(Map<String, dynamic>)? onMessageReceived;
  Function()? onConnectionChanged;
  Function(String ip, String deviceName)? onHostDiscovered;
  Function()? onDiscoveryTimeout;

  bool isRoleConnected(DeviceRole role) {
    if (!isHost) return false;
    return clientRoles.values.contains(role);
  }

  Future<void> startHost({int port = 8080}) async {
    isHost = true;
    currentRole = DeviceRole.host;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      debugPrint('Host started on ${_server!.address.address}:$port');

      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocket socket = await WebSocketTransformer.upgrade(request);
          _connectedClients.add(socket);
          onConnectionChanged?.call();

          socket.listen(
                (message) => _handleIncomingMessage(message, senderSocket: socket),
            onDone: () {
              _connectedClients.remove(socket);
              clientRoles.remove(socket);
              onConnectionChanged?.call();
            },
            onError: (error) {
              _connectedClients.remove(socket);
              clientRoles.remove(socket);
              onConnectionChanged?.call();
            },
          );
        } else {
          request.response..statusCode = HttpStatus.forbidden..close();
        }
      });

      _startDiscoveryResponder();
    } catch (e) {
      debugPrint('Failed to start host: $e');
    }
  }

  Future<void> _startDiscoveryResponder() async {
    try {
      _udpResponderSocket?.close();
      _udpResponderSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8888);
      _udpResponderSocket!.broadcastEnabled = true;
      _udpResponderSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = _udpResponderSocket!.receive();
          if (dg != null) {
            String incomingMsg = utf8.decode(dg.data).trim();
            if (incomingMsg == "PAINT_DISCOVER") {
              String deviceName = Platform.localHostname;
              _udpResponderSocket!.send(utf8.encode("PAINT_HOST:$deviceName"), dg.address, dg.port);
            }
          }
        }
      });
    } catch (e) {
      debugPrint("Discovery Responder error: $e");
    }
  }

  void stopDiscovery() {
    _udpDiscoverySocket?.close();
    _udpDiscoverySocket = null;
  }

  Future<void> startDiscovery() async {
    try {
      stopDiscovery();

      // Look up all active network adapters on the device
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      List<RawDatagramSocket> activeSockets = [];

      if (interfaces.isEmpty) {
        // Fallback to generic bind if no explicit interfaces are exposed
        final fallbackSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        fallbackSocket.broadcastEnabled = true;
        activeSockets.add(fallbackSocket);
      } else {
        // Fix for Windows: Bind a separate socket directly to each real interface IP
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            try {
              final s = await RawDatagramSocket.bind(addr, 0);
              s.broadcastEnabled = true;
              activeSockets.add(s);
            } catch (e) {
              debugPrint("Could not bind UDP discovery to ${addr.address}: $e");
            }
          }
        }
      }

      // Track the primary socket reference for the controller shutdown sequence
      _udpDiscoverySocket = activeSockets.isNotEmpty ? activeSockets.first : null;

      // Attach listeners to catch the host responses on all bound interfaces
      for (var socket in activeSockets) {
        socket.listen((RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            Datagram? dg = socket.receive();
            if (dg != null) {
              String msg = utf8.decode(dg.data).trim();
              if (msg.startsWith("PAINT_HOST:")) {
                String hostName = msg.substring("PAINT_HOST:".length);
                onHostDiscovered?.call(dg.address.address, hostName);
              }
            }
          }
        });
      }

      // Blast discovery signals down every physical pipeline
      for (int i = 0; i < 10; i++) {
        if (_udpDiscoverySocket == null) break; // Discovery was cancelled early

        for (var socket in activeSockets) {
          try {
            // Send to global broadcast target
            socket.send(utf8.encode("PAINT_DISCOVER"), InternetAddress("255.255.255.255"), 8888);

            // Also explicitly calculate and blast to the interface's local subnet (e.g. 192.168.1.255)
            final parts = socket.address.address.split('.');
            if (parts.length == 4) {
              final subnetBroadcast = "${parts}.${parts}.${parts}.255";
              socket.send(utf8.encode("PAINT_DISCOVER"), InternetAddress(subnetBroadcast), 8888);
            }
          } catch (e) {
            // Catch interface busy errors silently
          }
        }
        await Future.delayed(const Duration(seconds: 1));
      }

      // Gracefully close down the temporary tracking sockets
      for (var socket in activeSockets) {
        socket.close();
      }

      if (_udpDiscoverySocket != null) {
        _udpDiscoverySocket = null;
        onDiscoveryTimeout?.call();
      }
    } catch (e) {
      debugPrint("Discovery error: $e");
    }
  }

  Future<void> connectToHost(String ipAddress, {int port = 8080, required DeviceRole role}) async {
    isHost = false;
    currentRole = role;
    stopDiscovery();

    try {
      _clientConnection = await WebSocket.connect('ws://$ipAddress:$port');
      debugPrint('Connected to host at $ipAddress:$port');
      onConnectionChanged?.call();

      broadcast({'type': 'role_registration', 'role': role.toString()});

      _clientConnection!.listen(
            (message) => _handleIncomingMessage(message),
        onDone: () { _clientConnection = null; onConnectionChanged?.call(); },
        onError: (error) { _clientConnection = null; onConnectionChanged?.call(); },
      );
    } catch (e) {
      debugPrint('Failed to connect to host: $e');
    }
  }

  void broadcast(Map<String, dynamic> data) {
    final String jsonString = jsonEncode(data);
    if (isHost) {
      for (var client in _connectedClients) {
        client.add(jsonString);
      }
    } else if (_clientConnection != null) {
      _clientConnection!.add(jsonString);
    }
  }

  void _handleIncomingMessage(dynamic message, {WebSocket? senderSocket}) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);

      if (isHost && data['type'] == 'role_registration') {
        DeviceRole role = DeviceRole.values.firstWhere((e) => e.toString() == data['role']);
        clientRoles[senderSocket!] = role;
        onConnectionChanged?.call();
        return;
      }

      if (isHost) {
        for (var client in _connectedClients) {
          if (client != senderSocket) client.add(message);
        }
      }
      onMessageReceived?.call(data);
    } catch (e) {
      debugPrint("Error parsing incoming message: $e");
    }
  }

  void shutdown() {
    _udpResponderSocket?.close();
    _udpResponderSocket = null;
    stopDiscovery();

    if (isHost) {
      for (var client in _connectedClients) client.close();
      _connectedClients.clear();
      clientRoles.clear();
      _server?.close();
      _server = null;
    } else {
      _clientConnection?.close();
      _clientConnection = null;
    }

    currentRole = DeviceRole.host;
    isHost = true;
  }
}