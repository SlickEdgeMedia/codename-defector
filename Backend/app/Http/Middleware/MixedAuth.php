<?php

namespace App\Http\Middleware;

use App\Models\GuestToken;
use Closure;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;

class MixedAuth
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();

        if (! $user) {
            $guestToken = $this->extractToken($request);
            if ($guestToken) {
                $guest = GuestToken::where('token', $guestToken)->first();
                if ($guest) {
                    $guest->forceFill(['last_used_at' => now()])->saveQuietly();
                    $request->attributes->set('guest', $guest);
                }
            }
        } else {
            $request->attributes->set('user', $user);
        }

        if (! $request->attributes->has('user') && ! $request->attributes->has('guest')) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        return $next($request);
    }

    private function extractToken(Request $request): ?string
    {
        $authHeader = $request->header('Authorization');
        if (is_string($authHeader) && str_starts_with(strtolower($authHeader), 'bearer ')) {
            return trim(substr($authHeader, 7));
        }

        if ($request->hasHeader('X-Guest-Token')) {
            return $request->header('X-Guest-Token');
        }

        return null;
    }
}
