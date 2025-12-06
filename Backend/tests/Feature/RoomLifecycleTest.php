<?php

namespace Tests\Feature;

use App\Models\Room;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Redis;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RoomLifecycleTest extends TestCase
{
    use RefreshDatabase;

    public function test_host_can_create_room_and_is_ready(): void
    {
        $this->fakeRedis();

        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/rooms', [
            'nickname' => 'Captain',
            'rounds' => 3,
        ]);

        $response->assertCreated()
            ->assertJsonPath('room.host_user_id', $user->id)
            ->assertJsonPath('participant.is_host', true)
            ->assertJsonPath('participant.user.id', $user->id);

        $roomId = $response->json('room.id');
        $roomCode = $response->json('room.code');

        $this->assertNotEmpty($roomCode);
        $this->assertDatabaseHas('rooms', [
            'id' => $roomId,
            'code' => $roomCode,
            'host_user_id' => $user->id,
            'status' => Room::STATUS_LOBBY,
        ]);

        $this->assertDatabaseHas('room_participants', [
            'room_id' => $roomId,
            'user_id' => $user->id,
            'nickname' => 'Captain',
            'is_host' => true,
        ]);
    }

    public function test_guest_can_join_and_toggle_ready(): void
    {
        $this->fakeRedis();

        [$room, $host] = $this->createRoomAsHost();

        $guest = User::factory()->create();
        Sanctum::actingAs($guest);

        $join = $this->postJson("/api/rooms/{$room['code']}/join", [
            'nickname' => 'GuestOne',
        ]);

        $join->assertOk()
            ->assertJsonPath('participant.user_id', $guest->id)
            ->assertJsonPath('participant.is_host', false);

        $ready = $this->postJson("/api/rooms/{$room['code']}/ready", [
            'ready' => true,
        ]);

        $ready->assertOk()
            ->assertJsonPath('participant.user_id', $guest->id);

        $this->assertNotNull($ready->json('participant.ready_at'));
        $this->assertDatabaseHas('room_participants', [
            'room_id' => $room['id'],
            'user_id' => $guest->id,
        ]);
    }

    public function test_guest_leaving_does_not_close_room(): void
    {
        $this->fakeRedis();

        [$room, $host] = $this->createRoomAsHost();

        $guest = User::factory()->create();
        Sanctum::actingAs($guest);
        $this->postJson("/api/rooms/{$room['code']}/join", [
            'nickname' => 'GuestTwo',
        ])->assertOk();

        $this->postJson("/api/rooms/{$room['code']}/leave")
            ->assertOk()
            ->assertJsonPath('message', 'Left room.');

        $this->assertDatabaseHas('rooms', [
            'id' => $room['id'],
            'status' => Room::STATUS_LOBBY,
        ]);

        $this->assertDatabaseMissing('room_participants', [
            'room_id' => $room['id'],
            'user_id' => $guest->id,
        ]);
    }

    public function test_host_leaving_closes_room(): void
    {
        $this->fakeRedis();

        [$room, $host] = $this->createRoomAsHost();

        Sanctum::actingAs($host);

        $this->postJson("/api/rooms/{$room['code']}/leave")
            ->assertOk()
            ->assertJsonPath('message', 'Room closed by host.');

        $this->assertDatabaseHas('rooms', [
            'id' => $room['id'],
            'status' => Room::STATUS_ENDED,
        ]);

        $this->assertDatabaseCount('room_participants', 0);
    }

    private function createRoomAsHost(): array
    {
        $host = User::factory()->create();
        Sanctum::actingAs($host);

        $response = $this->postJson('/api/rooms', [
            'nickname' => 'HostNick',
        ])->assertCreated();

        return [$response->json('room'), $host];
    }

    private function fakeRedis(): void
    {
        Redis::shouldReceive('connection')->andReturnSelf();
        Redis::shouldReceive('publish')->andReturn(1);
    }
}
