---
name: create-ticket
description: "Create a Jira ticket in project ALL (board 876, Squad PDI) assigned to me, after asking which story it belongs under and whether it goes into the active sprint. Use when the user says 'create a ticket', 'make a ticket', 'open a Jira ticket', 'file this as a ticket' or similar, regardless of current working directory. Not for local TODOs - that is create-todo."
---

# Create a Jira ticket

Fixed values (site xainag.atlassian.net):

| what | value |
|---|---|
| cloudId | `9438f461-d8e0-4c5f-a7b9-9a8ba44ebc70` |
| project | `ALL` |
| board | `876` |
| assignee (me) | `712020:17ae936e-6e7a-4d29-ac08-57bffe856b97` |
| Team field | `customfield_10001` = Squad PDI `1a9c3660-12be-4ff3-abc9-40fdab27ecff` |
| Sprint field | `customfield_10020` |

## Steps

1. Draft the ticket from the conversation: a summary that states the change, and a markdown
   description with **Why**, the facts it rests on (numbers, paths, index names), a **To do**
   checklist, and anything that must not be forgotten. Link related tickets by key.
2. Find candidate parents: `searchJiraIssuesUsingJql` with
   `project = ALL AND assignee = "712020:17ae936e-6e7a-4d29-ac08-57bffe856b97" AND statusCategory != Done`
   plus a text filter on the topic. Check the parent of any ticket already named in the
   conversation or the current branch name (`ALL-NNNN-...`), since a sibling is the usual home.
3. Ask with `AskUserQuestion` (one call, two questions):
   - **Parent**: up to three candidate stories as "Sub-task of ALL-XXXX" (recommended one first,
     with its summary), plus "Standalone Task" (Other lets me name a new Story or another key).
   - **Sprint**: the board's active sprint (read it from the `Sprint` field of a recent ticket on
     board 876) vs backlog.
4. Create with `createJiraIssue`: `issueType` Sub-task with `parent`, or Task/Story without;
   `assignee` as above; `assignToSprint` with the sprint id if chosen.
   - Sub-tasks inherit the Team from their parent: do **not** pass `customfield_10001` (Jira
     rejects it). For a Task or Story, pass `{"customfield_10001": "1a9c3660-12be-4ff3-abc9-40fdab27ecff"}`.
   - A new Story needs its own parent decision; ask before creating two tickets.
5. Verify with `getJiraIssue` (fields `customfield_10020`, `customfield_10001`, `parent`) and
   report the key, link, parent, sprint and team.
