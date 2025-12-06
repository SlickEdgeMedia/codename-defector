<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('rooms', function (Blueprint $table) {
            $table->id();
            $table->string('code', 5)->unique();
            $table->foreignId('host_user_id')->constrained('users');
            $table->enum('status', ['lobby', 'in_round', 'ended'])->default('lobby');
            $table->unsignedTinyInteger('max_players')->default(10);
            $table->unsignedTinyInteger('rounds')->default(4);
            $table->unsignedSmallInteger('discussion_seconds')->default(300);
            $table->unsignedSmallInteger('voting_seconds')->default(60);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('rooms');
    }
};
