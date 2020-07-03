import socket
import time

server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
server.bind(("0.0.0.0", 2020))
print(server.getsockname())


class Client:
    def __init__(self, num, ext_ip, ext_port, int_ip, int_port):
        self.num = num
        self.ext_ip = ext_ip
        self.ext_port = ext_port
        self.int_ip = int_ip
        self.int_port = int_port

    def set_ext_ip(self, ip):
        self.ext_ip = ip

    def set_ext_port(self, port):
        self.ext_port = port

    def set_int_ip(self, ip):
        self.int_ip = ip

    def set_int_port(self, port):
        self.int_port = port


clients = []


def get_match(num):
    for c in clients:
        if c.num == num:
            return c
    return None


def send_diff(sock, device_in, device_out):
    dest_ip = device_out.ext_ip
    dest_port = device_out.ext_port
    nat_port = device_in.ext_port
    s_ip = device_in.ext_ip
    s_port = device_in.ext_port
    server.sendto(f"{dest_ip}:{dest_port}-{nat_port}".encode(), (s_ip, s_port))


def send_same(sock, device_in, device_out):
    dest_ip = device_out.int_ip
    dest_port = device_out.int_port
    nat_port = device_in.int_port
    s_ip = device_in.ext_ip
    s_port = device_in.ext_port
    server.sendto(f"{dest_ip}:{dest_port}-{nat_port}".encode(), (s_ip, s_port))


while True:
    data, address = server.recvfrom(1024)
    data = data.decode()
    print(data)
    request = data[0 : data.index(",")]

    clIp = data[data.index("-") + 1 : data.index(";")]
    clPort = data[data.index(";") + 1 : data.index("!")]

    if request == "Register":
        num = data[data.index(",") + 1 : data.index("-")]
        state = True
        ip = address[0]
        port = address[1]
        print("received request from", ip, str(port))
        client = Client(num, ip, port, clIp, clPort)
        for c in clients:
            if c.num == client.num:
                c.set_ext_ip(ip)
                c.set_ext_port(port)
                c.set_int_ip(clIp)
                c.set_int_port(clPort)
                state = False
                break
        if state:
            clients.append(client)

        registeredId = ""
        for c in clients:
            registeredId += "\n" + str(c.num)

        server.sendto(registeredId.encode(), (ip, port))

    elif request == "Connect":
        num = data[data.index(",") + 1 : data.index("-")]
        nat_port = data[data.index("-") + 1 : data.index("!")]
        ip = address[0]
        port = address[1]
        source = Client(32164, ip, port, clIp, clPort)
        match_device = get_match(num)
        if match_device is not None:
            if match_device.ext_ip == source.ext_ip:
                print(f"Behind same nat {source.ext_ip}")
                send_same(server, match_device, source)
                # time.sleep(2)
                send_same(server, source, match_device)
                # if clients.__contains__(source):
                #     clients.remove(source)
                # if clients.__contains__(client):
                #     clients.remove(client)
            else:
                print(
                    f"Behind different nat, s-{source.ext_ip}, d-{match_device.ext_ip}"
                )
                send_diff(server, match_device, source)
                # time.sleep(2)
                send_diff(server, source, match_device)
                # if clients.__contains__(source):
                #     clients.remove(source)
                # if clients.__contains__(client):
                #     clients.remove(client)
        else:
            print("destination not found")
            # if clients.__contains__(source):
            #     clients.remove(source)
            # if clients.__contains__(client):
            #     clients.remove(client)
