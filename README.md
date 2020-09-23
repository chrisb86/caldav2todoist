# caldav2todoist

Get tasks from a calDAV server and push them to Todoist.

I'm using my own Nextcloud for almost everything but I'm also a long time Todoist user.
I love to create tasks with Siri on my phone or watch. The way to plumb together Siri and Todoist that is recommended from Todoist ist to use IFTTT.

That's another third party that get's my data and it hasn't worked reliable for me in the last year. So I was looking for another way.

caldav2todoist is a simple shell script with no external dependencies on most modern systems (maybe curl and uuidgen).
It fetches the tasks from a given calDAV URL that were created since tha last run and uses the Todoist API to create the tasks in your Inbox.

Just set the needed variables, put the script in your crontab and you're ready to go.
```sh
# Your calDAV user
caldav_login="YOUR_USERNAME"
# Your calDAV password
caldav_password="YOUR_PASSWORD"
# URL of your calDAV calendar/tasklist
caldav_url="https://example.org/remote.php/dav/calendars/user/tasklist/"

# Your Todoist API token (get it at https://todoist.com/prefs/integrations)
todoist_api_token="YOUR_TODOIST_API_TOKEN"
```
