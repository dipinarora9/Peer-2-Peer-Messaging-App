## This project is under development. There might be some breaking changes.

### This app demonstrates Peer 2 Peer communication over UDP.
We are using UDP Nat-hole punching to achieve quick connection.

A host creates a Meeting id and uploads its socket details to a firebase db, the members join the
meeting via opening a meeting url or entering a meeting code.
Thus, the members also uploads their socket details under the same room id.
The server assigns a UID to each peer connecting to it and generates a routing table for that peer
and sends it.
After that each peer connects to their routing table peers.

#### Messaging explanation here

For now, we are allowing a maximum of 256 (2^8) peers.
Therefore each peer maintains a routing table of 8 outgoing peer and 7 incoming peers.

### Done

> Established communication between devices behind same as well as different NAT.

### Working on

> Peers are connecting to each other in Kademlia Distributed Hash Table format.

Project made by Dipin Arora (@dipinarora9) and Prashant Sajwan (@PRASHANT-SAJWAN)

[Link](https://files.ifi.uzh.ch/CSG/staff/bocek/extern/theses/BA-Jonas-Wagner.pdf] to reference paper) to the reference paper.
