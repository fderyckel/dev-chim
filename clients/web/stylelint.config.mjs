const config = {
  extends: ["stylelint-config-standard"],
  rules: {
    "declaration-no-important": true,
    "selector-class-pattern": [
      "^(?:l|c|u|is|has)-[a-z0-9]+(?:-[a-z0-9]+)*(?:__(?:[a-z0-9]+-?)+)?(?:--(?:[a-z0-9]+-?)+)?$",
      {
        message: "Class names must use the l-, c-, u-, is-, or has- ownership grammar.",
      },
    ],
    "selector-max-id": 0,
    "selector-disallowed-list": ["/:nth-(?:child|last-child)\\(/"],
    "selector-max-specificity": "0,3,0",
    "selector-not-notation": "simple",
  },
};

export default config;
