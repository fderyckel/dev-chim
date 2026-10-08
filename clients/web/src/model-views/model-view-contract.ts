export type ModelViewKind = "list" | "form" | "calendar" | "gantt";

export type ModelViewValue = string | number | boolean | null;

export type ModelViewRecord = Readonly<Record<string, ModelViewValue>>;

export type ModelViewField = Readonly<{
  ref: string;
  label: string;
  type: "text" | "date" | "number" | "status";
}>;

export type ListViewDefinition = Readonly<{
  kind: "list";
  fields: ReadonlyArray<string>;
}>;

export type FormViewDefinition = Readonly<{
  kind: "form";
  fields: ReadonlyArray<string>;
}>;

export type CalendarViewDefinition = Readonly<{
  kind: "calendar";
  titleField: string;
  startField: string;
  endField?: string;
  statusField?: string;
}>;

export type GanttViewDefinition = Readonly<{
  kind: "gantt";
  titleField: string;
  startField: string;
  endField: string;
  groupField?: string;
}>;

export type ModelViewDefinition =
  | ListViewDefinition
  | FormViewDefinition
  | CalendarViewDefinition
  | GanttViewDefinition;

export type ModelViewSetDefinition = Readonly<{
  schemaVersion: 1;
  sourceRef: string;
  title: string;
  identityField: string;
  fields: ReadonlyArray<ModelViewField>;
  views: ReadonlyArray<ModelViewDefinition>;
  defaultView: ModelViewKind;
}>;

const referencePattern = /^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*$/;

function referencedFields(view: ModelViewDefinition): ReadonlyArray<string> {
  switch (view.kind) {
    case "list":
    case "form":
      return view.fields;
    case "calendar":
      return [
        view.titleField,
        view.startField,
        ...(view.endField ? [view.endField] : []),
        ...(view.statusField ? [view.statusField] : []),
      ];
    case "gantt":
      return [
        view.titleField,
        view.startField,
        view.endField,
        ...(view.groupField ? [view.groupField] : []),
      ];
  }
}

export function validateModelViewSet(
  definition: ModelViewSetDefinition,
): ReadonlyArray<string> {
  const issues: string[] = [];
  const fields = new Map(definition.fields.map((field) => [field.ref, field]));
  const viewKinds = definition.views.map((view) => view.kind);

  if (definition.schemaVersion !== 1) {
    issues.push("The view definition schema version is unsupported.");
  }
  if (!referencePattern.test(definition.sourceRef)) {
    issues.push("The view source reference is invalid.");
  }
  if (!definition.title.trim() || definition.title.length > 120) {
    issues.push("The view set needs a bounded title.");
  }
  if (definition.fields.length === 0 || definition.fields.length > 32) {
    issues.push("A view set needs between 1 and 32 fields.");
  }
  if (fields.size !== definition.fields.length) {
    issues.push("View field references must be unique.");
  }
  if (!fields.has(definition.identityField)) {
    issues.push("The identity field must be declared.");
  }
  for (const field of definition.fields) {
    if (!referencePattern.test(field.ref) || !field.label.trim()) {
      issues.push("Every view field needs a valid reference and label.");
      break;
    }
  }
  if (definition.views.length === 0 || new Set(viewKinds).size !== viewKinds.length) {
    issues.push("View kinds must be non-empty and unique.");
  }
  if (!viewKinds.includes(definition.defaultView)) {
    issues.push("The default view must be one of the declared views.");
  }

  for (const view of definition.views) {
    const references = referencedFields(view);
    if (
      references.length === 0 ||
      new Set(references).size !== references.length ||
      references.some((reference) => !fields.has(reference))
    ) {
      issues.push(`${view.kind} view contains an unavailable field reference.`);
    }

    if (view.kind === "calendar" || view.kind === "gantt") {
      if (fields.get(view.startField)?.type !== "date") {
        issues.push(`${view.kind} view requires a date-valued start field.`);
      }
    }
    if (view.kind === "calendar" && view.endField) {
      if (fields.get(view.endField)?.type !== "date") {
        issues.push("calendar view requires a date-valued end field.");
      }
    }
    if (view.kind === "gantt" && fields.get(view.endField)?.type !== "date") {
      issues.push("gantt view requires a date-valued end field.");
    }
  }

  return [...new Set(issues)];
}

export function viewDefinition(
  definition: ModelViewSetDefinition,
  kind: ModelViewKind,
): ModelViewDefinition | undefined {
  return definition.views.find((view) => view.kind === kind);
}

export function fieldDefinition(
  definition: ModelViewSetDefinition,
  fieldRef: string,
): ModelViewField | undefined {
  return definition.fields.find((field) => field.ref === fieldRef);
}
