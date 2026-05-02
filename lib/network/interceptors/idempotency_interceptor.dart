import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/network/models/api_request.dart';
import 'package:flutter_production_kit/network/tracing/request_trace.dart';

/// Idempotency interceptor — adds idempotency keys to dangerous requests.
///
/// Design rationale:
/// - Payment and critical endpoints MUST include an idempotency key.
/// - If the caller provides one, it's passed through as-is.
/// - If not provided, a deterministic key is generated from the request
///   (method + path + normalized body) so identical requests get the same key.
/// - The key is sent as the `Idempotency-Key` header.
/// - The interceptor validates that critical endpoints have a key before
///   allowing the request through (enforced by [DangerousEndpointGuard]).
class IdempotencyInterceptor {
  IdempotencyInterceptor({
    this.idempotencyHeader = 'Idempotency-Key',
    this.idempotencyKeyPrefix = 'idemp_',
  });

  static const String _tag = 'IdempotencyInterceptor';

  final String idempotencyHeader;
  final String idempotencyKeyPrefix;

  /// Apply idempotency key to the request.
  http.Request apply({
    required http.Request request,
    required ApiRequestContext context,
    required RequestTrace trace,
  }) {
    // Only add idempotency keys for non-GET requests.
    if (context.method == HttpMethod.get) {
      return request;
    }

    // Use caller-provided key if available.
    if (context.idempotencyKey != null && context.idempotencyKey!.isNotEmpty) {
      request.headers[idempotencyHeader] = '${idempotencyKeyPrefix}${context.idempotencyKey}';
      trace.addPhase(
        name: 'idempotency',
        duration: Duration.zero,
        success: true,
        detail: 'caller_key_used',
      );
      return request;
    }

    // Generate a deterministic key for non-critical writes.
    final generatedKey = _generateKey(context);
    request.headers[idempotencyHeader] = '${idempotencyKeyPrefix}auto_$generatedKey';

    trace.addPhase(
      name: 'idempotency',
      duration: Duration.zero,
      success: true,
      detail: 'auto_key_generated',
    );

    return request;
  }

  String _generateKey(ApiRequestContext context) {
    final components = [
      context.method.value,
      context.path,
      _stableBodyHash(context.body),
    ].join('|');

    final hash = sha256.convert(utf8.encode(components));
    return hash.toString().substring(0, 16);
  }

  String _stableBodyHash(Map<String, dynamic>? body) {
    if (body == null) return '';

    // Sort keys for deterministic hash.
    final sorted = Map.fromEntries(
      body.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    return jsonEncode(sorted);
  }
}
