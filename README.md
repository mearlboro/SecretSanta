# Secret Santa mailer
### A tool to send secret Santa emails without anyone knowing the pairings

This is a Perl script which generates a random set of pairs from the names and
emails provided in a text file, excluding some pairs if provided, then sends
emails to everyone about who to buy a present for, from an email alias
`santa@northpole.org`.

Until 2020, this script could send emails directly from any machine running
Perl and a SMTP server, for example `sendmail`. These would land in Spam but
still be delivered. More recently, due to issues with mail deliverability, it
is now recommended to use the mailservers of an existing mail provider. At the
time of writing the best free solution is Gmail, which allows sending 100 emails
per day for free. To configure this, line 18 in the `secret_santa.pl` script
should be populated with a Gmail account (without `@gmail.com`) and password.

The sender alias will remain `santa@northpole.com` but the messages will actually
be sent from the Gmail account that was setup on line 18.

The emails are still sent via the underlying mailserver on the computer used to
run the script, but they are sent via the Gmail (or whichever else) relay is
configured. Therefore you must make sure this mailserver is running and well
configured

```bash
sudo systemctl status sendmail
```

Note that at the moment emails won't be relayed correctlty if the computer is
running a VPN without the firewall properly configured.

