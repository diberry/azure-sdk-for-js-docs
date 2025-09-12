import { AgentsClient } from "@azure/ai-agents";
import { DefaultAzureCredential } from "@azure/identity";

const projectEndpoint = process.env["PROJECT_ENDPOINT"] || "<project endpoint>";
const modelDeploymentName = process.env["MODEL_DEPLOYMENT_NAME"] || "gpt-4o";

export async function main(): Promise<void> {
  // Create an Azure AI Client
  const client = new AgentsClient(projectEndpoint, new DefaultAzureCredential());

  // Create an agent
  const agent = await client.createAgent(modelDeploymentName, {
    name: "my-agent",
    instructions: "You are a helpful agent specialized in math. When providing mathematical explanations, use plain text formatting with simple characters like +, -, *, / for operations. Do not use LaTeX formatting with backslashes or special notation. Make your explanations clear and easy to read in a terminal.",
  });
  console.log(`Created agent, agent ID : ${agent.id}`);

  // Create a thread
  const thread = await client.threads.create();
  console.log(`Created thread, thread ID : ${thread.id}`);

  // List all threads for the agent
  const threads = client.threads.list();
  console.log(`Threads for agent ${agent.id}:`);
  for await (const t of threads) {
    console.log(`Thread ID: ${t.id} created at: ${t.createdAt}`);
  }

  // Create a message
  const message = await client.messages.create(thread.id, "user", "I need to solve the equation `3x + 11 = 14`. Can you help me?");
  console.log(`Created message, message ID : ${message.id}`);

  // Create and poll a run
  console.log("Creating run...");
  const run = await client.runs.createAndPoll(thread.id, agent.id, {
    pollingOptions: {
      intervalInMs: 2000,
    },
    onResponse: (response): void => {
      const parsedBody =
        typeof response.parsedBody === "object" && response.parsedBody !== null
          ? response.parsedBody
          : null;
      const status = parsedBody && "status" in parsedBody ? parsedBody.status : "unknown";
      console.log(`Received response with status: ${status}`);
    },
  });
  console.log(`Run finished with status: ${run.status}`);

  const messagesIterator = client.messages.list(thread.id);
  console.log("\n\n========================================================");
  console.log("=================== CONVERSATION RESULTS ===================");
  console.log("========================================================\n");
  
  // Collect all messages first
  const messages = [];
  for await (const m of messagesIterator) {
    messages.push(m);
  }
  
  // Reverse the order of messages (or sort by timestamp if available)
  messages.reverse();
  
  // Display messages in the new order
  for (const m of messages) {
    if (m.role === "user") {
      console.log(`\n❓ USER QUESTION: ${
        Array.isArray(m.content) && m.content[0]?.type === "text" && 'text' in m.content[0]
          ? m.content[0].text.value
          : JSON.stringify(m.content)
      }`);
    } else if (m.role === "assistant") {
      console.log("\n🤖 ASSISTANT'S ANSWER:");
      console.log("--------------------------------------------------");
      
      // Extract and print the text content in a more readable format
      if (m.content && Array.isArray(m.content)) {
        for (const content of m.content) {
          if (content.type === "text" && 'text' in content) {
            console.log(content.text?.value);
          } else {
            console.log(content);
          }
        }
      } else {
        console.log(JSON.stringify(m.content, null, 2));
      }
      console.log("--------------------------------------------------\n");
    }
  }
  
  console.log("\n========================================================");
  console.log("====================== END OF RESULTS ======================");
  console.log("========================================================\n");

  // Clean up
  await client.threads.delete(thread.id);
  console.log(`Deleted thread, thread ID: ${thread.id}`);

  // Delete agent
  await client.deleteAgent(agent.id);
  console.log(`Deleted agent, agent ID: ${agent.id}`);
}

main().catch((err) => {
  console.error("The sample encountered an error:", err);
});