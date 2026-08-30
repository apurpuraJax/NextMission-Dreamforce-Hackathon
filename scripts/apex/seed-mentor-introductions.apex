// Seed NM_Mentor_Introduction__c records
// Creates 15 introductions across all Status values (Pending/Sent/Declined)
// Links to existing Conversations and Mentors in the org
// Note: Name is auto-number — omitted from inserts

// ── Fetch Conversation IDs by name ─────────────────────────────────────────
Map<String, Id> convMap = new Map<String, Id>();
for (NM_Conversation__c c : [
    SELECT Id, Name FROM NM_Conversation__c
    WHERE Name IN ('CONV-0000','CONV-0001','CONV-0002','CONV-0003','CONV-0004',
                   'CONV-0005','CONV-0006','CONV-0007','CONV-0008','CONV-0009',
                   'CONV-0010','CONV-0011','CONV-0012')
]) {
    convMap.put(c.Name, c.Id);
}

// ── Fetch Mentor IDs by name ────────────────────────────────────────────────
Map<String, Id> mentorMap = new Map<String, Id>();
for (NM_Mentor__c m : [
    SELECT Id, Name FROM NM_Mentor__c
    WHERE Name IN ('Devon S.','Casey W.','Jordan M.','Riley K.','Quinn A.',
                   'Sage P.','Avery L.','Morgan T.','Cameron J.','Taylor B.',
                   'Parker N.','Alex R.','Reese H.','Blake V.','Sam D.')
]) {
    mentorMap.put(m.Name, m.Id);
}

System.debug('Conversations found: ' + convMap.size());
System.debug('Mentors found: ' + mentorMap.size());

if (convMap.isEmpty() || mentorMap.isEmpty()) {
    System.debug('ERROR: Missing conversations or mentors — aborting seed');
    return;
}

// ── Build introduction records ──────────────────────────────────────────────
// 6 Sent, 5 Pending, 4 Declined
List<NM_Mentor_Introduction__c> intros = new List<NM_Mentor_Introduction__c>();

// SENT — successfully introduced, varied dates
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0001'),
    Mentor__c          = mentorMap.get('Quinn A.'),
    Requester_Email__c = 'veteran01@nextmission.org',
    Status__c          = 'Sent',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 1, 10, 0, 0)
));
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0002'),
    Mentor__c          = mentorMap.get('Devon S.'),
    Requester_Email__c = 'veteran02@nextmission.org',
    Status__c          = 'Sent',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 5, 14, 30, 0)
));
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0004'),
    Mentor__c          = mentorMap.get('Casey W.'),
    Requester_Email__c = 'veteran04@nextmission.org',
    Status__c          = 'Sent',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 8, 9, 0, 0)
));
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0005'),
    Mentor__c          = mentorMap.get('Cameron J.'),
    Requester_Email__c = 'veteran05@nextmission.org',
    Status__c          = 'Sent',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 12, 11, 0, 0)
));
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0010'),
    Mentor__c          = mentorMap.get('Taylor B.'),
    Requester_Email__c = 'veteran10@nextmission.org',
    Status__c          = 'Sent',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 15, 16, 0, 0)
));
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0011'),
    Mentor__c          = mentorMap.get('Avery L.'),
    Requester_Email__c = 'veteran11@nextmission.org',
    Status__c          = 'Sent',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 20, 10, 30, 0)
));

// PENDING — awaiting mentor response
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0000'),
    Mentor__c          = mentorMap.get('Alex R.'),
    Requester_Email__c = 'veteran00@nextmission.org',
    Status__c          = 'Pending',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 22, 9, 0, 0)
));
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0003'),
    Mentor__c          = mentorMap.get('Riley K.'),
    Requester_Email__c = 'veteran03@nextmission.org',
    Status__c          = 'Pending',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 24, 14, 0, 0)
));
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0008'),
    Mentor__c          = mentorMap.get('Jordan M.'),
    Requester_Email__c = 'veteran08@nextmission.org',
    Status__c          = 'Pending',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 26, 11, 0, 0)
));
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0009'),
    Mentor__c          = mentorMap.get('Parker N.'),
    Requester_Email__c = 'veteran09@nextmission.org',
    Status__c          = 'Pending',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 27, 10, 0, 0)
));
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0012'),
    Mentor__c          = mentorMap.get('Blake V.'),
    Requester_Email__c = 'veteran12@nextmission.org',
    Status__c          = 'Pending',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 28, 15, 0, 0)
));

// DECLINED — mentor unavailable or mismatch
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0006'),
    Mentor__c          = mentorMap.get('Sam D.'),
    Requester_Email__c = 'veteran06@nextmission.org',
    Status__c          = 'Declined',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 10, 9, 0, 0)
));
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0007'),
    Mentor__c          = mentorMap.get('Reese H.'),
    Requester_Email__c = 'veteran07@nextmission.org',
    Status__c          = 'Declined',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 13, 13, 0, 0)
));
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0001'),
    Mentor__c          = mentorMap.get('Morgan T.'),
    Requester_Email__c = 'veteran01b@nextmission.org',
    Status__c          = 'Declined',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 18, 16, 0, 0)
));
intros.add(new NM_Mentor_Introduction__c(
    Conversation__c    = convMap.get('CONV-0003'),
    Mentor__c          = mentorMap.get('Sage P.'),
    Requester_Email__c = 'veteran03b@nextmission.org',
    Status__c          = 'Declined',
    Introduced_At__c   = DateTime.newInstance(2026, 8, 25, 10, 0, 0)
));

// ── Insert ──────────────────────────────────────────────────────────────────
try {
    insert intros;
    System.debug('SUCCESS: Inserted ' + intros.size() + ' NM_Mentor_Introduction__c records');
    System.debug('  Sent: 6  Pending: 5  Declined: 4');
} catch (DmlException e) {
    System.debug('DML ERROR: ' + e.getMessage());
    System.debug('First failure: ' + e.getDmlMessage(0));
}
