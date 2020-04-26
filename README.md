## This project is in active development. There might be some breaking changes.

### This app demonstrates Peer2Peer communication over TCP.

Right now, when the devices try to get into enter a network.
The first device automatically becomes a server (acting as a Booting peer for the network).
After that when a device tries to enter the network it automatically becomes a client (peer/node).
The server assigns a UID to each peer connecting to it and generates a routing table for that peer and sends it.

For now, because only devices work in a LAN there can be a maximum of 256 (2^8) nodes in a /24 subnet.
Therefore each peer maintains a routing table of 8 outgoing peer and 7 incoming peers.

### Done
> Peers are connecting to each other in Kademlia Distributed Hash Table format.

> Send message to a particular user in the same LAN without Internet connectivity.

> We are successful in Nat Hole Punching behind the same NAT to establish peer2peer communication over WAN.

### Left
> Working on establishing communication between devices behind different NAT.

Project made by Dipin Arora (@dipinarora9) and Prashant Sajwan (@PRASHANT-SAJWAN)