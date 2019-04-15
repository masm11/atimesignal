package me.masm11.atimesignal

import android.content.Intent
import com.google.firebase.messaging.FirebaseMessagingService

class MessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String?) {
        android.util.Log.d("onNewToken", "Refreshed token: $token")

	val intent = Intent(this, TokenSenderService::class.java)
		.putExtra(TokenSenderService.TOKEN, token)
	startService(intent)
    }
}
