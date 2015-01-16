namespace :active_record do
	desc "Clear expired sessions"

	task :clear_expired_sessions => :environment do
		ActiveRecord::SessionStore::Session.delete_all(["updated_at < ?", 24.hours.ago])
	end
end
