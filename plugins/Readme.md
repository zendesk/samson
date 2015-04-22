Plugins is WIP and might change at any time.

Plugins use hooks to add views/assets/models to samson and otherwise work like rails engines.

Amend models by defining app/models/decorators/{model}_decorator.rb, it will be auto-loaded when the underlying model is loaded.
