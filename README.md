# Wazuh-tools-etc
Collection of Wazuh tools, rules etc.


## wazuh_win_dns_debug

Can be used to log Windows DNS Server logs into Wazuh.  
Logging via Microsoft-Windows-DNSServer/Analytical ETW logging channel didnt really work for me, so I used the DNS debug log for that.  
This might not be feasible for environments with a huge amount of queries, but for me it was working fine.

Just start the debug log and write the logs into a file of your liking, include the file in the agent.conf like this:

```
  <agent_config>
      <localfile>
          <log_format>syslog</log_format>
          <location>C:\Dns\DNS.log</location>
    </localfile>
</agent_config>
```

Then the decoder and ruleset can be used to ingest the data from the logfile.
The DNS queries are in the DNS wire-format, but for my use case this was sufficient.
