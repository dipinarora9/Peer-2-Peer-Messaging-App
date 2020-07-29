### This app demonstrates Peer 2 Peer communication over UDP.

We are using UDP Nat-hole punching to achieve quick connection.

A host creates a room id and uploads its socket details to a firebase DB, the members join the meeting via a meeting url or entering a meeting id. Thus, the members also upload their socket details under the same room id. As soon as, a member uploads it's detailing to the firebase DB under the same room is the host peer gets notified that a person with X name is trying to enter the meeting, if the hosts allow him, a numbering is assigned to him and a routing table for that peer/member is generated. Also, some dummy(empty) messages are sent to start UDP hole punching. If his entrance is denied then nothing happens and the member gets notified that he cannot enter. Each peer requests it's routing table from the server initially. The routing table is based on Kademlia Distributed Hash Table format.

For now, we are allowing a maximum of 256 (2^8) peers. Therefore each peer maintains a routing table of max 8 outgoing peer and 7 incoming peer details.

Each peer pings it's outgoing peers on a time interval to check if they are dead or alive. If a peer fails to respond 3 consecutive responses to ping messages. A dead request is sent to the host/server peer that we then first try pinging the peer if it responds then the peer which sent the dead request is responded with a Not dead message. Else if it doesn't respond, it's routing table is calculated and then all it's concerned peer is provided with the information that this peer is dead.

The same kind of procedure happens when a new peer enters a network, all its concerned peers are informed to update their routing table themselves upon the entry of this new peer.

Each peer is made smart enough to recalculate its routing table based on the last node number in the network.

Each member peer sends dummy messages to its incoming peer upon getting a routing table or upon its updation, so as to establish UDP hole punching.

#### There are two ways to send a message:
• Broadcast message (which gets received by everyone)
• Private message (gets to a particular person)

We have completed the broadcast messaging part and will be completing the private messaging very soon.

### This project is made by Dipin Arora (@dipinarora9) and Prashant Sajwan (@PRASHANT-SAJWAN)

### [Link](https://files.ifi.uzh.ch/CSG/staff/bocek/extern/theses/BA-Jonas-Wagner.pdf) to the reference paper.
