abstract class Message {}

/// A message passed from the client to the server.
abstract class ClientMessage extends Message {}

/// A message passed from the server to the client.
abstract class ServerMessage extends Message {}

/// A message sent with a [requestId] value.
abstract class RequestMessage extends Message {
  abstract final int requestId;
}

/// A message that is the response to a [RequestMessage]
/// containing the same [requestId]
abstract class ResponseMessage extends Message {
  abstract final int requestId;
}

abstract class OneWayMessage extends Message {}

/// A Request from the client
abstract class ClientRequestMessage implements ClientMessage, RequestMessage {}
