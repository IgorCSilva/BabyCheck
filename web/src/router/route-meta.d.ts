import "vue-router";

declare module "vue-router" {
  interface RouteMeta {
    requiresAuth?: boolean;
    guestOnly?: boolean;
    // Every log in later steps is scoped to a baby, so these routes
    // bounce to /babies until at least one exists.
    requiresBaby?: boolean;
  }
}
