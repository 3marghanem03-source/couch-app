class ClientDetails {
  const ClientDetails({
    required this.clientId,
    required this.coachId,
    required this.publicBio,
    required this.goals,
    required this.injuries,
    required this.privateNotes,
  });

  final String clientId;
  final String coachId;
  final String publicBio;
  final String goals;
  final String injuries;
  final String privateNotes;
}

