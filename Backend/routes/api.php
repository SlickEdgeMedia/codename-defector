<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\GuestController;
use App\Http\Controllers\Api\RoomController;
use App\Http\Controllers\Api\RoundController;
use Illuminate\Support\Facades\Route;

Route::middleware('throttle:auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/guest', [GuestController::class, 'store']);
});

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);
});

Route::middleware('auth.mixed')->group(function () {
    Route::get('/auth/introspect', [AuthController::class, 'introspect']);

    Route::middleware('throttle:rooms')->group(function () {
        Route::post('/rooms', [RoomController::class, 'store']);
        Route::get('/rooms/{code}', [RoomController::class, 'show']);
        Route::post('/rooms/{code}/join', [RoomController::class, 'join']);
        Route::post('/rooms/{code}/leave', [RoomController::class, 'leave']);
        Route::post('/rooms/{code}/ready', [RoomController::class, 'setReady']);

        Route::post('/rooms/{code}/rounds/start', [RoundController::class, 'start']);
        Route::get('/rounds/{roundId}/role', [RoundController::class, 'role']);
        Route::post('/rounds/{roundId}/questions', [RoundController::class, 'askQuestion']);
        Route::post('/rounds/{roundId}/answers', [RoundController::class, 'answerQuestion']);
        Route::post('/rounds/{roundId}/votes', [RoundController::class, 'vote']);
        Route::post('/rounds/{roundId}/guess', [RoundController::class, 'imposterGuess']);
        Route::get('/rounds/{roundId}/results', [RoundController::class, 'results']);
    });
});
