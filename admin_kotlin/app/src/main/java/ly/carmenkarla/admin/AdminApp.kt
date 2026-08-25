package ly.carmenkarla.admin

import android.app.Application
import ly.carmenkarla.admin.data.Repository
import ly.carmenkarla.admin.notify.WithdrawalNotifier
import ly.carmenkarla.admin.notify.WithdrawalPollWorker

class AdminApp : Application() {

    lateinit var repository: Repository
        private set

    override fun onCreate() {
        super.onCreate()
        repository = Repository(this)
        instance = this
        WithdrawalNotifier.ensureChannel(this)
        WithdrawalPollWorker.schedule(this)
    }

    companion object {
        lateinit var instance: AdminApp
            private set
    }
}
