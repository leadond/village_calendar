/// Result of asking to join a village by invite code.
class JoinRequestResult {
  const JoinRequestResult(this.status, {this.villageName, this.requestedRole});

  /// One of: not_found, already_member, pending, error.
  final String status;
  final String? villageName;
  final String? requestedRole;

  bool get isPending => status == 'pending';
  bool get isAlreadyMember => status == 'already_member';
  bool get notFound => status == 'not_found';
}

/// The signed-in user's own outstanding (pending) join request.
class PendingJoin {
  const PendingJoin({
    required this.requestId,
    required this.villageId,
    required this.villageName,
  });

  final String requestId;
  final String villageId;
  final String villageName;
}

/// A pending request shown to a village admin for approval.
class JoinRequestItem {
  const JoinRequestItem({
    required this.requestId,
    required this.requesterId,
    required this.displayName,
    required this.email,
    required this.createdAt,
    required this.requestedRole,
  });

  final String requestId;
  final String requesterId;
  final String displayName;
  final String email;
  final DateTime createdAt;
  final String requestedRole;
}
