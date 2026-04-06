import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "create_plan",
    label: "Create Plan",
    description:
      "Create or update an implementation plan with structured tasks and dependencies. " +
      "Use this tool when the user asks you to plan, break down, or create an epic for a piece of work. " +
      "Each task should have a unique id, clear title, optional description, and list of dependency task ids.",
    parameters: Type.Object({
      epic_title: Type.String({ description: "Title for the epic/plan" }),
      tasks: Type.Array(
        Type.Object({
          id: Type.String({ description: 'Unique task identifier, e.g. "task-1"' }),
          title: Type.String({ description: "Short task title" }),
          description: Type.Optional(Type.String({ description: "Detailed task description" })),
          dependencies: Type.Optional(
            Type.Array(Type.String(), { description: "IDs of tasks that must complete before this one" })
          ),
        })
      ),
    }),

    async execute(toolCallId, params, signal, onUpdate) {
      return {
        content: [
          {
            type: "text",
            text: `Plan created: "${params.epic_title}" with ${params.tasks.length} tasks.`,
          },
        ],
        details: params,
      };
    },
  });
}
