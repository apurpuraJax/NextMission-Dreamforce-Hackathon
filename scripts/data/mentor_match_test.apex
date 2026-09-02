// Read-only: NM_FindMentor_Flow selects a mentor, it does not write anything.
Map<String,String> cases = new Map<String,String>{
 'avionics tech, never flew'      => 'Air Force avionics technician, 20 years on F-16 avionics systems, never a pilot, wants aircraft maintenance work',
 'combat medic'                   => 'Army 68W combat medic, emergency care under fire, wants civilian paramedic or hospital work',
 'navy IT'                        => 'Navy Information Systems Technician, shipboard networks and servers, wants civilian IT',
 'truck driver'                   => 'Army 88M motor transport operator, drove convoys, wants civilian truck driving',
 'military spouse admin'          => 'Military spouse, front desk and medical billing, moves every two years, needs portable remote work',
 'coast guard boatswain'          => 'Coast Guard Boatswains Mate, deck operations and small boats, wants port or maritime work'
};
for (String k : cases.keySet()) {
    Map<String,Object> ins = new Map<String,Object>{
        'description' => cases.get(k), 'clusterKey' => '' };
    Flow.Interview f = Flow.Interview.createInterview('NM_FindMentor_Flow', ins);
    f.start();
    System.debug('MATCH ' + k + ' -> ' + f.getVariableValue('mentorName')
        + ' (' + f.getVariableValue('mentorCivilianRole') + ')');
}
