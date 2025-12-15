<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GuestToken;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class GuestController extends Controller
{
    public function store(Request $request)
    {
        $data = $request->validate([
            'nickname' => 'required|string|min:3|max:20',
        ]);

        $token = Str::random(48);

        $guest = GuestToken::create([
            'token' => $token,
            'nickname' => $data['nickname'],
            'last_used_at' => now(),
        ]);

        return response()->json([
            'token' => $guest->token,
            'guest' => [
                'nickname' => $guest->nickname,
            ],
        ], 201);
    }
}
