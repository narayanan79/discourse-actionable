import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "actionable-icons",

  initialize() {
    withPluginApi("1.6.0", (api) => {
      // Register actionable icons in the icon library
      api.replaceIcon("d-unactioned", "far-check-square");
      api.replaceIcon("d-actioned", "check-square");

      // Alternative icons that can be used
      // api.replaceIcon("d-unactioned", "far-square");
      // api.replaceIcon("d-actioned", "check");

      // Add custom CSS classes for different icon states
      api.onPageChange(() => {
        const style = document.createElement("style");
        style.textContent = `
          /* Unactioned state - outline check square */
          .d-icon-far-check-square {
            color: var(--primary-medium);
          }
          
          /* Actioned state - solid check square */  
          .d-icon-check-square {
            color: var(--success);
          }
          
          /* Hover states */
          .actionable:hover .d-icon-far-check-square {
            color: var(--success);
          }
          
          .has-actionable:hover .d-icon-check-square {
            color: var(--primary-medium);
          }
          
          /* Disabled state */
          .toggle-actionable[disabled] .d-icon {
            color: var(--primary-medium);
          }
          
          /* Animation support */
          .check-animation .d-icon {
            transform-origin: center;
          }
        `;

        if (!document.querySelector("#actionable-icon-styles")) {
          style.id = "actionable-icon-styles";
          document.head.appendChild(style);
        }
      });
    });
  },
};
