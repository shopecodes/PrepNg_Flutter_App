import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connectivity
  Future<bool> hasInternetConnection() async {
    try {
      // First check if connected to WiFi or Mobile data
      final connectivityResult = await _connectivity.checkConnectivity();
      
      // Check if the list contains 'none' - means no connection
      if (connectivityResult.contains(ConnectivityResult.none) || connectivityResult.isEmpty) {
        return false;
      }

      // Verify actual internet access by pinging a reliable server
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Stream to listen to connectivity changes
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  /// Check connectivity type without actual internet verification
  Future<List<ConnectivityResult>> getConnectivityType() async {
    return await _connectivity.checkConnectivity();
  }
}