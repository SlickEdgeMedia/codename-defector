import 'dotenv/config';
import { createServer } from 'http';
import { Server } from 'socket.io';
import Redis from 'ioredis';

// Global error handlers to prevent crashes
process.on('uncaughtException', (error) => {
    console.error('Uncaught exception:', error);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled rejection at:', promise, 'reason:', reason);
});

const port = Number(process.env.SOCKET_PORT ?? 6001);
const socketPath = process.env.SOCKET_PATH ?? '/socket.io';
const redisUrl = process.env.SOCKET_REDIS_URL ?? 'redis://127.0.0.1:6379';
const apiBaseUrl = (process.env.LARAVEL_API_URL ?? 'http://localhost:8000/api').replace(/\/$/, '');
const roomEventsChannel = process.env.ROOM_EVENTS_CHANNEL ?? 'imposter:rooms';
const allowedOrigins = process.env.SOCKET_ALLOWED_ORIGINS
    ? process.env.SOCKET_ALLOWED_ORIGINS.split(',').map((origin) => origin.trim()).filter(Boolean)
    : ['*'];

const httpServer = createServer();

// Redis client for room events only (no Socket.IO adapter needed for single server)
const roomEventsClient = new Redis(redisUrl, { maxRetriesPerRequest: null });

const logRedisError = (label) => (error) => {
    console.error(`[redis:${label}]`, error?.message ?? error);
};

roomEventsClient.on('error', logRedisError('room-events'));

const io = new Server(httpServer, {
    path: socketPath,
    cors: {
        origin: allowedOrigins,
        methods: ['GET', 'POST'],
    },
});

// No Redis adapter needed - we only have one Socket.IO server

roomEventsClient.subscribe(roomEventsChannel, (error) => {
    if (error) {
        console.error(`Redis subscribe failed for ${roomEventsChannel}`, error);
    } else {
        console.log(`Listening for room events on ${roomEventsChannel}`);
    }
});

roomEventsClient.on('message', (channel, message) => {
    if (channel !== roomEventsChannel) {
        return;
    }

    try {
        const event = JSON.parse(message);

        if (!event?.room_code || !event?.type) {
            return;
        }

        console.log(`Redis event -> emit ${event.type} to room:${event.room_code}`);
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

        const actor = await validateToken(token);
        const room = await fetchRoomMembership(roomCode, token, actor);

        if (!room) {
            throw new Error('Not a member of this room');
        }

        socket.data.actor = actor;
        socket.data.roomCode = room.code;
        socket.data.token = token;

        console.log(
            `Auth ok for socket ${socket.id} room=${room.code} actor=${actor.type}:${actor.type === 'user' ? actor.id : actor.token?.slice(0, 6) + '...'}`,
        );

        return next();
    } catch (error) {
        console.error('Auth failed', error?.message ?? error);
        return next(error);
    }
});

io.on('connection', (socket) => {
    const roomChannel = getRoomChannel(socket.data.roomCode);
    socket.join(roomChannel);

    console.log(`Socket ${socket.id} joined ${roomChannel}`);

    socket.emit('connected', {
        room_code: socket.data.roomCode,
        actor: socket.data.actor,
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
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 5000); // 5 second timeout

  try {
    const response = await fetch(`${apiBaseUrl}/auth/introspect`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/json',
      },
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new Error(`Token rejected (${response.status})`);
    }

    const payload = await response.json();

    if (payload.type === 'user' && payload.user) {
      return { type: 'user', id: payload.user.id, name: payload.user.name };
    }

    if (payload.type === 'guest' && payload.guest) {
      return { type: 'guest', token: payload.guest.token, nickname: payload.guest.nickname };
    }

    throw new Error('Invalid token payload');
  } catch (error) {
    clearTimeout(timeoutId);
    throw error;
  }
}

async function fetchRoomMembership(roomCode, token, actor) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 5000); // 5 second timeout

  try {
    const response = await fetch(`${apiBaseUrl}/rooms/${roomCode}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/json',
      },
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    if (!response.ok) {
      console.error(`Room fetch failed ${response.status}`);
      return null;
    }

    const body = await response.json();
    const room = body?.data ?? body; // handle Laravel resource wrapper
    const participants = room?.participants ?? [];
    const isMember = participants.some((participant) => {
      if (actor.type === 'user') {
        return participant.user_id === actor.id;
      }
      return participant.guest_token === actor.token;
    });

    return isMember ? room : null;
  } catch (error) {
    clearTimeout(timeoutId);
    console.error('Room membership fetch error:', error.message);
    return null;
  }
}

function getRoomChannel(roomCode) {
  return `room:${roomCode}`;
}
