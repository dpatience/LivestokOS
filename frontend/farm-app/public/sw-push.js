/** Service worker push + notification handler (imported by Workbox). */
self.addEventListener("push", (event) => {
  let data = { title: "LivestokOS alert", body: "High-severity alert", tag: "alert" };
  try {
    if (event.data) {
      data = { ...data, ...event.data.json() };
    }
  } catch {
    // use defaults
  }

  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      tag: data.tag,
      icon: "/icon-192.png",
      badge: "/icon-192.png",
      requireInteraction: true,
    }),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if ("focus" in client) {
          client.navigate("/alerts");
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow("/alerts");
      }
    }),
  );
});

self.addEventListener("message", (event) => {
  if (event.data?.type === "SHOW_ALERT_NOTIFICATION") {
    const { title, body, tag } = event.data.payload;
    event.waitUntil(
      self.registration.showNotification(title, {
        body,
        tag: tag ?? "alert",
        icon: "/icon-192.png",
        badge: "/icon-192.png",
        requireInteraction: true,
      }),
    );
  }
});
