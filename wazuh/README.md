Ubuntu Benchmark 22.04 Workstation Level 1 v1.0.0

* This folder contains the wazuh sca specification yml file tuned for workstation level 1

note: some of the rules have not been implemented yet:
1. 1.5.1 Ensure address space layout randomization (ASLR) is enabled (Automated) - Not implemented 
2. 1.8.2 Ensure GDM login banner is configured (Automated) - Not implemented # 1.8.3 Ensure GDM disable-user-list option is enabled (Automated) - Not implemented 
3. 1.8.4 Ensure GDM screen locks when the user is idle (Automated) - Not implemented 
4. 1.8.5 Ensure GDM screen locks cannot be overridden (Automated) - Not implemented # 1.8.8 Ensure GDM autorun-never is enabled (Automated) -  Not implemented 
5. 1.8.9 Ensure GDM autorun-never is not overridden (Automated) - Not implemented 
6. 1.9 Ensure updates, patches, and additional security software are installed (Manual) - Not implemented 
7. 2.1.1 Ensure time synchronization is in use 
8. 2.1.2.1 Ensure chrony is configured with authorized timeserver (Manual) - Not implemented
9. 2.1.3.1 Ensure systemd-timesyncd configured with authorized timeserver (Manual) - Not implemented
10. 2.1.4.2 Ensure ntp is configured with authorized timeserver (Manual) - Not implemented
11. 2.4 Ensure nonessential services are removed or masked (Manual) - Not implemented
12. 3.1.1 Ensure system is checked to determine if IPv6 is enabled (Manual) - Not implemented
13. 3.2.1 Ensure packet redirect sending is disabled (Automated) - Not implemented
14. 3.2.2 Ensure IP forwarding is disabled (Automated) - Not implemented
15. 3.3.1 Ensure source routed packets are not accepted (Automated) - Not implemented
16. 3.3.2 Ensure ICMP redirects are not accepted (Automated) - Not implemented
17. 3.3.3 Ensure secure ICMP redirects are not accepted (Automated) - Not implemented
18. 3.3.4 Ensure suspicious packets are logged (Automated) - Not implemented
19. 3.3.5 Ensure broadcast ICMP requests are ignored (Automated) - Not implemented
20. 3.3.6 Ensure bogus ICMP responses are ignored (Automated) - Not implemented
21. 3.3.7 Ensure Reverse Path Filtering is enabled (Automated) - Not implemented
22. 3.3.8 Ensure TCP SYN Cookies is enabled (Automated) - Not implemented
23. 3.3.9 Ensure IPv6 router advertisements are not accepted (Automated) - Not implemented
24. 3.5.1.5 Ensure ufw outbound connections are configured (Manual) - Not implemented
25. 3.5.1.6 Ensure ufw firewall rules exist for all open ports (Automated) - Not implemented
26. 3.5.2.2 Ensure ufw is uninstalled or disabled with nftables (Automated) - Not implemented
27. 3.5.2.3 Ensure iptables are flushed with nftables (Manual) - Not implemented
28. 3.5.2.6 Ensure nftables loopback traffic is configured (Automated) - Not implemented
29. 3.5.2.7 Ensure nftables outbound and established connections are configured (Manual) - Not implemented
30. 3.5.2.10 Ensure nftables rules are permanent (Automated) - Not implemented
31. 3.5.3.2.3 Ensure iptables outbound and established connections are configured (Manual) - Not implemented
32. 3.5.3.2.4 Ensure iptables firewall rules exist for all open ports (Automated) - Not implemented
33. 3.5.3.3.3 Ensure ip6tables outbound and established connections are configured (Manual) - Not implemented
34. 3.5.3.3.4 Ensure ip6tables firewall rules exist for all open ports (Automated) - Not implemented
35. 4.1.4.1 Ensure audit log files are mode 0640 or less permissive (Automated) - Not implemented
36. 4.1.4.2 Ensure only authorized users own audit log files (Automated) - Not implemented
37. 4.1.4.4 Ensure the audit log directory is 0750 or more restrictive (Automated) - Not implemented
38. 4.2.1.1.1 Ensure systemd-journal-remote is installed (Manual) - Not implemented
39. 4.2.1.1.2 Ensure systemd-journal-remote is configured (Manual) - Not implemented
40. 4.2.1.1.3 Ensure systemd-journal-remote is enabled (Manual) - Not implemented
41. 4.2.1.6 Ensure journald log rotation is configured per site policy (Manual) - Not implemented
42. 4.2.1.7 Ensure journald default file permissions configured (Manual) - Not implemented
43. 4.2.2.5 Ensure logging is configured (Manual) - Not implemented
44. 4.2.2.6 Ensure rsyslog is configured to send logs to a remote log host (Manual) - Not implemented
45. 4.2.3 Ensure all logfiles have appropriate permissions and ownership (Automated) - Not implemented
46. 5.2.2 Ensure permissions on SSH private host key files are configured (Automated) - Not implemented
47. 5.2.3 Ensure permissions on SSH public host key files are configured (Automated) - Not implemented
48. 5.4.5 Ensure all current passwords uses the configured hashing algorithm (Manual) - Not implemented
49. 5.5.1.5 Ensure all users last password change date is in the past (Automated) -Not implemented
50. 5.5.2 Ensure system accounts are secured (Automated) - Not implemented
51. 5.5.4 Ensure default user umask is 027 or more restrictive (Automated) - Not implemented
52. 5.5.5 Ensure default user shell timeout is 900 seconds or less (Automated) - Not implemented
53. 6.1.9 Ensure no world writable files exist (Automated) - Not implemented
54. 6.1.10 Ensure no unowned files or directories exist (Automated) - Not implemented
55. 6.1.11 Ensure no ungrouped files or directories exist (Automated) - Not implemented
56. 6.1.12 Audit SUID executables (Manual) - Not implemented
57. 6.1.13 Audit SGID executables (Manual) - Not implemented
58. 6.2.3 Ensure all groups in /etc/passwd exist in /etc/group (Automated) - Not implemented
59. 6.2.5 Ensure no duplicate UIDs exist (Automated) - Not implemented
60. 6.2.6 Ensure no duplicate GIDs exist (Automated) - Not implemented
61. 6.2.7 Ensure no duplicate user names exist (Automated) - Not implemented
62. 6.2.8 Ensure no duplicate group names exist (Automated) - Not implemented
63. 6.2.9 Ensure root PATH Integrity (Automated) - Not implemented
64. 6.2.11 Ensure local interactive user home directories exist (Automated) - Not implemented
65. 6.2.12 Ensure local interactive users own their home directories (Automated) - Not implemented
66. 6.2.13 Ensure local interactive user home directories are mode 750 or more restrictive (Automated) - Not implemented
67. 6.2.14 Ensure no local interactive user has .netrc files (Automated) - Not implemented
68. 6.2.15 Ensure no local interactive user has .forward files (Automated) - Not implemented
69. 6.2.16 Ensure no local interactive user has .rhosts files (Automated) - Not implemented
70. 6.2.17 Ensure local interactive user dot files are not group or world writable (Automated) - Not implemented
