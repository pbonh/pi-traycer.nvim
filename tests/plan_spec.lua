describe("plan", function()
  local plan
  local test_dir

  before_each(function()
    package.loaded["pi-traycer.plan"] = nil
    plan = require("pi-traycer.plan")
    test_dir = vim.fn.tempname()
    vim.fn.mkdir(test_dir, "p")
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
  end)

  describe("create_epic", function()
    it("creates epic with id and title", function()
      local epic = plan.create_epic("Test Feature", test_dir)
      assert.is_string(epic.id)
      assert.are.equal("Test Feature", epic.title)
      assert.are.equal("draft", epic.status)
      assert.are.same({}, epic.tasks)
    end)

    it("persists epic to JSON file", function()
      local epic = plan.create_epic("Test Feature", test_dir)
      local path = test_dir .. "/" .. epic.id .. ".json"
      assert.are.equal(1, vim.fn.filereadable(path))
    end)
  end)

  describe("load_epic", function()
    it("loads persisted epic", function()
      local epic = plan.create_epic("Test Feature", test_dir)
      package.loaded["pi-traycer.plan"] = nil
      plan = require("pi-traycer.plan")
      local loaded = plan.load_epic(epic.id, test_dir)
      assert.are.equal("Test Feature", loaded.title)
      assert.are.equal(epic.id, loaded.id)
    end)

    it("returns nil for missing epic", function()
      local loaded = plan.load_epic("nonexistent", test_dir)
      assert.is_nil(loaded)
    end)
  end)

  describe("set_tasks", function()
    it("sets tasks from create_plan tool output", function()
      local epic = plan.create_epic("Auth System", test_dir)
      local tasks = {
        { id = "task-1", title = "DB schema", description = "Create tables" },
        { id = "task-2", title = "Login endpoint", dependencies = { "task-1" } },
      }
      plan.set_tasks(epic.id, tasks, test_dir)
      local loaded = plan.load_epic(epic.id, test_dir)
      assert.are.equal(2, #loaded.tasks)
      assert.are.equal("task-1", loaded.tasks[1].id)
      assert.are.equal("pending", loaded.tasks[1].status)
      assert.are.same({ "task-1" }, loaded.tasks[2].dependencies)
    end)
  end)

  describe("update_task_status", function()
    it("updates task status", function()
      local epic = plan.create_epic("Test", test_dir)
      plan.set_tasks(epic.id, {
        { id = "task-1", title = "First task" },
      }, test_dir)
      plan.update_task_status(epic.id, "task-1", "active", test_dir)
      local loaded = plan.load_epic(epic.id, test_dir)
      assert.are.equal("active", loaded.tasks[1].status)
    end)

    it("cycles status pending -> active -> done -> pending", function()
      local epic = plan.create_epic("Test", test_dir)
      plan.set_tasks(epic.id, {
        { id = "task-1", title = "First task" },
      }, test_dir)
      assert.are.equal("pending", plan.load_epic(epic.id, test_dir).tasks[1].status)
      plan.toggle_task_status(epic.id, "task-1", test_dir)
      assert.are.equal("active", plan.load_epic(epic.id, test_dir).tasks[1].status)
      plan.toggle_task_status(epic.id, "task-1", test_dir)
      assert.are.equal("done", plan.load_epic(epic.id, test_dir).tasks[1].status)
      plan.toggle_task_status(epic.id, "task-1", test_dir)
      assert.are.equal("pending", plan.load_epic(epic.id, test_dir).tasks[1].status)
    end)
  end)

  describe("list_epics", function()
    it("lists all epics in directory", function()
      plan.create_epic("Epic A", test_dir)
      plan.create_epic("Epic B", test_dir)
      local epics = plan.list_epics(test_dir)
      assert.are.equal(2, #epics)
    end)
  end)
end)
