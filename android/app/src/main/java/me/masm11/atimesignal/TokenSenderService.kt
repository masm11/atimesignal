package me.masm11.atimesignal

import android.app.IntentService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import java.net.URL
import javax.net.ssl.HttpsURLConnection

class TokenSenderService : IntentService("TokenSenderService") {
    companion object {
	val TOKEN = "me.masm11.atimesignal.TOKEN"
	val URL_TO_REGISTER = "https://www.masm11.me/atimesignal/register"
    }

    private fun showToast(message: String) {
	val msg = message
	Handler(Looper.getMainLooper()).post(object: Runnable {
	    override fun run() {
		Toast.makeText(getApplicationContext(), msg, Toast.LENGTH_LONG).show()
	    }
	})
    }

    override fun onHandleIntent(intent: Intent) {

	val token = intent.getStringExtra(TOKEN)
	android.util.Log.d("TokenSenderService", "token: ${token}")

	val url = URL(URL_TO_REGISTER)
	var conn: HttpsURLConnection? = null
	try {
	    conn = url.openConnection() as HttpsURLConnection
	    conn.setRequestMethod("POST")
	    conn.setDoInput(false)
	    conn.setDoOutput(true)
	    conn.connect()
	    val out = conn.getOutputStream()
	    val json = "{\"token\":\"${token}\"}" as String
	    out.write(json.toByteArray())
	    out.flush()
	    if (conn.getResponseCode() != 200) {
		showToast("HTTP ${conn.getResponseCode()} ${conn.getResponseMessage()}")
	    } else {
		showToast("Token sent.")
	    }
	} catch (e: Exception) {
	    // message = e.toString()
	    showToast(e.toString())
	} finally {
	    if (conn != null)
		conn.disconnect();
	}

	android.util.Log.d("TokenSenderService", "done.")

    }

}


