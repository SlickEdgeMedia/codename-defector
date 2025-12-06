<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\RoomParticipantResource;
use App\Http\Resources\RoomResource;
use App\Models\Room;
use App\Models\RoomParticipant;
use App\Services\RoomEventPublisher;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class RoomController extends Controller
{
    public function __construct(private readonly RoomEventPublisher $publisher)
    {
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'nickname' => 'required|string|min:3|max:20',
            'rounds' => 'sometimes|integer|min:1|max:10',
            'discussion_seconds' => 'sometimes|integer|min:30|max:900',
            'voting_seconds' => 'sometimes|integer|min:10|max:180',
            'max_players' => 'sometimes|integer|min:3|max:12',
        ]);

        [$room, $participant] = DB::transaction(function () use ($request, $data) {
            $room = Room::create([
                'code' => $this->generateUniqueCode(),
                'host_user_id' => $request->user()->id,
                'rounds' => $data['rounds'] ?? 4,
                'discussion_seconds' => $data['discussion_seconds'] ?? 300,
                'voting_seconds' => $data['voting_seconds'] ?? 60,
                'max_players' => $data['max_players'] ?? 10,
            ]);

            $participant = RoomParticipant::create([
                'room_id' => $room->id,
                'user_id' => $request->user()->id,
                'nickname' => $data['nickname'],
                'is_host' => true,
                'ready_at' => now(),
            ]);

            return [$room->fresh(['participants.user']), $participant->fresh('user')];
        });

        $this->publisher->broadcast('room.created', $room, [
            'user_id' => $participant->user_id,
        ]);

        return response()->json([
            'room' => new RoomResource($room),
            'participant' => new RoomParticipantResource($participant),
        ], 201);
    }

    public function show(Request $request, string $code): RoomResource
    {
        $room = Room::query()
            ->where('code', strtoupper($code))
            ->with(['participants.user'])
            ->firstOrFail();

        $isMember = $room->participants->contains(fn ($participant) => $participant->user_id === $request->user()->id);

        if (! $isMember && $room->host_user_id !== $request->user()->id) {
            abort(403, 'You are not a member of this room.');
        }

        return new RoomResource($room);
    }

    public function join(Request $request, string $code): JsonResponse
    {
        $data = $request->validate([
            'nickname' => 'required|string|min:3|max:20',
        ]);

        $room = Room::where('code', strtoupper($code))->withCount('participants')->firstOrFail();

        if ($room->status !== Room::STATUS_LOBBY) {
            return response()->json(['message' => 'Room is not accepting players.'], 422);
        }

        $existingParticipant = RoomParticipant::where('room_id', $room->id)
            ->where('user_id', $request->user()->id)
            ->first();

        if (! $existingParticipant && $room->participants_count >= $room->max_players) {
            return response()->json(['message' => 'Lobby is full.'], 422);
        }

        $participant = RoomParticipant::updateOrCreate(
            ['room_id' => $room->id, 'user_id' => $request->user()->id],
            [
                'nickname' => $data['nickname'],
                'is_host' => $request->user()->id === $room->host_user_id,
            ],
        );

        $room->load(['participants.user']);
        $participant->load('user');

        $this->publisher->broadcast('room.joined', $room, [
            'user_id' => $participant->user_id,
        ]);

        return response()->json([
            'room' => new RoomResource($room),
            'participant' => new RoomParticipantResource($participant),
        ]);
    }

    public function leave(Request $request, string $code): JsonResponse
    {
        $room = Room::where('code', strtoupper($code))->firstOrFail();

        $participant = RoomParticipant::where('room_id', $room->id)
            ->where('user_id', $request->user()->id)
            ->first();

        if (! $participant) {
            return response()->json(['message' => 'You are not in this room.'], 404);
        }

        $participant->delete();

        if ($request->user()->id === $room->host_user_id) {
            $room->update(['status' => Room::STATUS_ENDED]);
            $room->participants()->delete();

            $this->publisher->broadcast('room.closed', $room, [
                'reason' => 'host_left',
            ]);

            return response()->json(['message' => 'Room closed by host.']);
        }

        $room->load(['participants.user']);

        $this->publisher->broadcast('room.left', $room, [
            'user_id' => $request->user()->id,
        ]);

        return response()->json([
            'message' => 'Left room.',
            'room' => new RoomResource($room),
        ]);
    }

    public function setReady(Request $request, string $code): JsonResponse
    {
        $data = $request->validate([
            'ready' => 'required|boolean',
        ]);

        $room = Room::where('code', strtoupper($code))->firstOrFail();

        if ($room->status !== Room::STATUS_LOBBY) {
            return response()->json(['message' => 'Cannot toggle ready outside lobby.'], 422);
        }

        $participant = RoomParticipant::where('room_id', $room->id)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        $participant->update([
            'ready_at' => $data['ready'] ? now() : null,
        ]);

        $participant->load('user');
        $room->load(['participants.user']);

        $this->publisher->broadcast('room.ready_updated', $room, [
            'user_id' => $participant->user_id,
            'ready_at' => optional($participant->ready_at)?->toIso8601String(),
        ]);

        return response()->json([
            'message' => 'Ready status updated.',
            'participant' => new RoomParticipantResource($participant),
            'room' => new RoomResource($room),
        ]);
    }

    private function generateUniqueCode(): string
    {
        do {
            $code = Str::upper(Str::random(5));
        } while (Room::where('code', $code)->exists());

        return $code;
    }
}
