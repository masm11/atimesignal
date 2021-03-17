package me.masm11.atimesignal

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.content.Intent
import com.google.firebase.messaging.FirebaseMessaging
import com.google.android.gms.tasks.OnCompleteListener

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

	FirebaseMessaging.getInstance().getToken()
	    .addOnCompleteListener(OnCompleteListener { task ->
		if (!task.isSuccessful) {
		    android.util.Log.w("MainActivity", "getInstanceid failed.", task.exception)
		} else {
		    val token = task.result

		    if (token != null) {
			val intent = Intent(this, TokenSenderService::class.java)
			    .putExtra(TokenSenderService.TOKEN, token)
			startService(intent)
		    }
		}
	    })
    }
}
