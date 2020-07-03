import socket
import time

server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
server.bind(("0.0.0.0", 2020))
print(server.getsockname())

while True:
    data, address = server.recvfrom(1)
    server.sendto(f'{address[0]}:{address[1]}'.encode(), address)
