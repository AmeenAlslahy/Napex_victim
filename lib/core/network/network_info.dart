import 'package:connectivity_plus/connectivity_plus.dart';

/// معلومات الشبكة
class NetworkInfo {
  NetworkInfo(this._connectivity);

  final Connectivity _connectivity;

  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Stream<bool> get onConnectionChange =>
      _connectivity.onConnectivityChanged.map(
        (results) => !results.contains(ConnectivityResult.none),
      );
}
