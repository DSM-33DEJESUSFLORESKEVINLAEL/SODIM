# 📱 SODIM - Flutter App

Aplicación móvil desarrollada en Flutter para la gestión de órdenes de trabajo, marbetes y bitácoras. Soporta funcionamiento **offline/online**, sincronización de datos y generación de PDF.

---

## 📌 Getting Started

Este proyecto es un punto de partida para una aplicación Flutter.


## 📦 Versiones y Cambios

Aquí se documentan los cambios por versión realizados en la app:


### ✅ Versión 1.2
🗓️ *[2025-06-04]*  
🔧 Cambios realizados:
- Se modificó la funcion para guardar los datos con o sin internet 

---


### ✅ Versión 1.1
🗓️ *[2025-06-03]*  
🔧 Cambios realizados:
- Se modificó la vista `nueva_orden` para que, al presionar el botón **Aceptar**, navegue directamente a la vista `marbetes_forms` pasando la orden recién creada como parámetro.

---

### ✅ Versión 1.0
🗓️ *[2025-05-XX]*  
🔧 Versión inicial:
- Captura de órdenes y marbetes.
- Almacenamiento local con SQLite.
- Sincronización con backend (API Delphi).
- Generación de PDF de órdenes.
- Validaciones y diseño estilizado.
- Autenticación por clave de vendedor.

---

## 🏗️ En desarrollo / Próximas versiones

- Versión 1.2 (planeada)
  - Agregar notificaciones de sincronización.
  - Vista para historial de cambios en marbetes.
  - Mejoras visuales en los formularios.

---

## 🚀 Publicación

Para compilar una versión personalizada:
```bash
flutter build apk --flavor prod -t lib/main_prod.dart
flutter build apk --flavor dev -t lib/main_dev.dart
