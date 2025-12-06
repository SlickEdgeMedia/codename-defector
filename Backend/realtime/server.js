import 'dotenv/config';
import { createServer } from 'http';
import { Server } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';

const port = Number(process.env.SOCKET_PORT ?? 6001);
const socketPath = process.env.SOCKET_PATH ?? '/socket.io';
const redisUrl = process.env.SOCKET_REDIS_URL ?? 'redis://127.0.0.1:6379';
const apiBaseUrl = (process.env.LARAVEL_API_URL ?? 'http://localhost:8000/api').replace(/\/$/, '');
const roomEventsChannel = process.env.ROOM_EVENTS_CHANNEL ?? 'imposter:rooms';
const allowedOrigins = process.env.SOCKET_ALLOWED_ORIGINS
    ? process.env.SOCKET_ALLOWED_ORIGINS.split(',').map((origin) => origin.trim()).filter(Boolean)
    : ['*'];

const httpServer = createServer();
const pubClient = new Redis(redisUrl);
const subClient = pubClient.duplicate();

const io = new Server(httpServer, {
    path: socketPath,
    cors: {
        origin: allowedOrigins,
        methods: ['GET', 'POST'],
    },
});

io.adapter(createAdapter(pubClient, subClient));

subClient.subscribe(roomEventsChannel, (error) => {
    if (error) {
        console.error(`Redis subscribe failed for ${roomEventsChannel}`, error);
    } else {
        console.log(`Listening for room events on ${roomEventsChannel}`);
    }
});

subClient.on('message', (channel, message) => {
    if (channel !== roomEventsChannel) {
        return;
    }

    try {
        const event = JSON.parse(message);

        if (!event?.room_code || !event?.type) {
            return;
        }

        io.to(getRoomChannel(event.room_code)).emit(event.type, event);
    } catch (error) {
        console.error('Failed to process room event', error);
    }
});

io.use(async (socket, next) => {
    try {
        const token = extractToken(socket);
        const roomCode = extractRoomCode(socket);

        if (!token) {
            throw new Error('Missing token');
        }

        if (!roomCode) {
            throw new Error('Missing room code');
        }

        const user = await validateToken(token);
        const room = await fetchRoomMembership(roomCode, token, user.id);

        if (!room) {
            throw new Error('Not a member of this room');
        }

        socket.data.user = user;
        socket.data.roomCode = room.code;
        socket.data.token = token;

        return next();
    } catch (error) {
        return next(error);
    }
});

io.on('connection', (socket) => {
    const roomChannel = getRoomChannel(socket.data.roomCode);
    socket.join(roomChannel);

    socket.emit('connected', {
        room_code: socket.data.roomCode,
        user_id: socket.data.user.id,
    });

    socket.on('disconnect', (reason) => {
        console.log(`Socket ${socket.id} disconnected from ${roomChannel}: ${reason}`);
    });
});

httpServer.listen(port, () => {
    console.log(`Socket.IO listening on :${port}${socketPath}`);
});

function extractToken(socket) {
    const token = socket.handshake.auth?.token ?? socket.handshake.headers.authorization;

    if (typeof token === 'string' && token.toLowerCase().startsWith('bearer ')) {
        return token.slice(7);
    }

    return typeof token === 'string' ? token : '';
}

function extractRoomCode(socket) {
    const code = socket.handshake.auth?.roomCode ?? socket.handshake.query.roomCode;

    return typeof code === 'string' ? code.toUpperCase() : '';
}

async function validateToken(token) {
    const response = await fetch(`${apiBaseUrl}/auth/introspect`, {
        headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/json',
        },
    });

    if (!response.ok) {
        throw new Error(`Token rejected (${response.status})`);
    }

    const payload = await response.json();

    return payload.user;
}

async function fetchRoomMembership(roomCode, token, userId) {
    const response = await fetch(`${apiBaseUrl}/rooms/${roomCode}`, {
        headers: {
            Authorization: `Bearer ${token}`,
            Accept: 'application/json',
        },
    });

    if (!response.ok) {
        return null;
    }

    const room = await response.json();
    const participants = room.participants ?? [];
    const isMember = participants.some((participant) => participant.user_id === userId);

    return isMember ? room : null;
}

function getRoomChannel(roomCode) {
    return `room:${roomCode}`;
}
