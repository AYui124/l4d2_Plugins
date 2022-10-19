// listening socket example for the socket extension

#include <sourcemod>
#include <socket>

public Plugin:myinfo = {
	name = "listen socket example",
	author = "Player",
	description = "This example provides a simple echo server",
	version = "1.0.1",
	url = "http://www.player.to/"
};
 
public OnPluginStart() {
	// enable socket debugging (only for testing purposes!)
	SocketSetOption(INVALID_HANDLE, DebugMode, 1);


	// create a new tcp socket
	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
	// bind the socket to all interfaces, port 50000
	SocketBind(socket, "0.0.0.0", 23456);
	// let the socket listen for incoming connections
	SocketListen(socket, OnSocketIncoming);
}

public OnSocketIncoming(Handle:socket, Handle:newSocket, String:remoteIP[], remotePort, any:arg) {
	PrintToServer("%s:%d connected", remoteIP, remotePort);

	// setup callbacks required to 'enable' newSocket
	// newSocket won't process data until these callbacks are set
	SocketSetReceiveCallback(newSocket, OnChildSocketReceive);
	SocketSetDisconnectCallback(newSocket, OnChildSocketDisconnected);
	SocketSetErrorCallback(newSocket, OnChildSocketError);

	SocketSend(newSocket, "成功连接\n");
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:ary) {
	// a socket error occured
	PrintToServer("error1");
	LogError("socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(socket);
}

public OnChildSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:hFile) {
	// send (echo) the received data back
	LogMessage(receiveData);
	SocketSend(socket, receiveData);
	// close the connection/socket/handle if it matches quit
	if (strncmp(receiveData, "quit", 4) == 0) 
	{
		PrintToServer("客户端发送退出请求");
		CloseHandle(socket);
	}
}

public OnChildSocketDisconnected(Handle:socket, any:hFile) {
	// remote side disconnected
	PrintToServer("客户端断开连接");
	CloseHandle(socket);
}

public OnChildSocketError(Handle:socket, const errorType, const errorNum, any:ary) {
	// a socket error occured

	LogError("child socket error %d (errno %d)", errorType, errorNum);
	PrintToServer("error2");
	CloseHandle(socket);
}
