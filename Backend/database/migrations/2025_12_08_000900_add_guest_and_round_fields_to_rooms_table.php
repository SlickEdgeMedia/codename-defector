<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('rooms', function (Blueprint $table) {
            if (! Schema::hasColumn('rooms', 'host_guest_token')) {
                $table->string('host_guest_token', 64)->nullable()->after('host_user_id');
            }

            if (! Schema::hasColumn('rooms', 'category')) {
                $table->string('category', 50)->default('countries')->after('voting_seconds');
            }

            if (! Schema::hasColumn('rooms', 'round_duration_seconds')) {
                $table->unsignedSmallInteger('round_duration_seconds')->default(300)->after('category');
            }

            if (! Schema::hasColumn('rooms', 'last_active_at')) {
                $table->timestamp('last_active_at')->nullable()->after('round_duration_seconds');
            }
        });
    }

    public function down(): void
    {
        Schema::table('rooms', function (Blueprint $table) {
            if (Schema::hasColumn('rooms', 'host_guest_token')) {
                $table->dropColumn('host_guest_token');
            }
            if (Schema::hasColumn('rooms', 'category')) {
                $table->dropColumn('category');
            }
            if (Schema::hasColumn('rooms', 'round_duration_seconds')) {
                $table->dropColumn('round_duration_seconds');
            }
            if (Schema::hasColumn('rooms', 'last_active_at')) {
                $table->dropColumn('last_active_at');
            }
        });
    }
};
