I found that sometimes the code can have bugs and the test can go to infinite loop. It's not a big problem when you run only a single test because it has a small timeout and process can be killed quite quickly.
The problem is when a full test pack is running, because it has TIMEOUT_BASE = 10 seconds and + 3 seconds for each test file from TIMEOUT_PER_EXTRA.
In that case if the infinite loop error appears on some test it will infinitely log to file the error for a lot of time.
It it possible to modify .bat files to check if log file has repeating lines at the end and kill process if it's happened?
Try to reproduce that error on some test and try add a kill process mechanism to current gdunit bat files.

debug> 
Debugger Break, Reason: 'Invalid access to property or key 'current_health' on a base object of type 'previously freed'.'
*Frame 0 - res://test/Systems/Items/test_chain_lightning_modifier.gd:28 in function 'test_chain_lightnin_modifier'
Enter "help" for assistance.
debug> 
Debugger Break, Reason: 'Invalid access to property or key 'current_health' on a base object of type 'previously freed'.'
*Frame 0 - res://test/Systems/Items/test_chain_lightning_modifier.gd:28 in function 'test_chain_lightnin_modifier'
Enter "help" for assistance.
debug> 