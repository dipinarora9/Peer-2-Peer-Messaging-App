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

/// Server :
///
/// 1. unique url generate + generate record sheet against that id
/// 2. server incoming + outgoing routing tables send (for punching)
/// 3. host needs to be updated
/// 4. each peer should have two connections - one with server just for regularly updating its routing table..
/// other connections will be with 19 other peers.
/// 5. connection to the server will have two types...
/// i) Peer connection
/// ii) Server connection
///
/// Client:
///
/// 1. Send dummy messages to incoming.
/// 2. Send actual message to outgoing.
/// 3. Create a separate connection with the server to update routing tables.

/*
* Creation of meeting
*
* Register user on firebase
*
* Server port
* Client port
*
* database ->  create new unique room and add host details
* generate url -> containing uuid of room and host details
*
* join room -> members will add their details in db and setup connection with the host at server port

* Server  (uid) -> routing
* client ()-> routing table
*/

Project made by Dipin Arora (@dipinarora9) and Prashant Sajwan (@PRASHANT-SAJWAN)

[Link](https://files.ifi.uzh.ch/CSG/staff/bocek/extern/theses/BA-Jonas-Wagner.pdf) to the reference paper.
