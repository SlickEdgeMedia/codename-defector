import { io } from "socket.io-client";

const token = "2|8Ta0lcoGapBGYlDPIwQlDRVKza5924hTE480vDEE33cfea2b";
const roomCode = "PRN98"; // e.g., ABCDF

const socket = io("http://localhost:6001", {
  path: "/socket.io",
  auth: { token, roomCode },
});

socket.on("connect", () => console.log("connected", socket.id));
socket.on("connected", (p) => console.log("server ack", p));
socket.on("room.created", console.log);
socket.on("room.joined", console.log);
socket.on("room.ready_updated", console.log);
socket.on("room.left", console.log);
socket.on("room.closed", console.log);
socket.on("connect_error", (err) => console.error("connect_error", err.message));
socket.on("disconnect", (reason) => console.log("disconnected", reason));
