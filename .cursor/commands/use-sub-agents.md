breakdown the given task into sub-tasks
for each sub-task, use `agent --model auto --print --output-format text "example prompt"`
to create a subagent to get the sub-task done.

note some of the sub-agents may get scared to do edits/run commands so in those
cases give it plenty of assurances that it is safe to proceed with the work

you can parralleize your calls to the sub-agents by using `parallel`
or any of the parrallelization tools available.