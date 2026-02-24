# 🌌 Eldritch Dossier — Compendio Enciclopédico

> **"Lo más misericordioso del mundo es la incapacidad de la mente humana para relacionar todos sus contenidos."** — *Inspirado en el horror cósmico de H.P. Lovecraft.*

**Eldritch Dossier** es una Aplicación Web Progresiva (PWA) de vanguardia diseñada para investigadores de lo oculto y entusiastas de la mitología. Permite catalogar y gestionar descubrimientos sobre criaturas ancestrales mediante una interfaz inmersiva que fusiona la estética de manuscritos antiguos con tecnología web de última generación.

![Texto ALT de la imagen que utilices para mostrar el proyecto](https://raw.githubusercontent.com/AguirreBrian/Eldritch-Dossier/refs/heads/main/assets/bestias/ED.png)

## ✨ Características Principales

### 💾 Arquitectura Offline-First
Desarrollada para funcionar en la oscuridad total. Utiliza **IndexedDB** para el almacenamiento local, garantizando acceso a tus investigaciones incluso sin conexión a la red.

### ☁️ Sincronización en la Nube
Integración nativa con la **API de GitHub Gists**. Persiste y sincroniza tu base de datos personal entre múltiples dispositivos utilizando tokens de acceso seguro.

### 👁️ Interfaz Inmersiva
Experiencia de usuario basada en **Glassmorphism**. Incluye:
* Animaciones de partículas en **Canvas 2D**.
* Efectos de profundidad con **Parallax**.
* Tipografía clásica seleccionada (`Cinzel` y `Crimson Text`) para una lectura atmosférica.

### 📝 Gestión Completa (CRUD)
Control total sobre los registros de criaturas, incluyendo:
* Origen (Cultura, Mitología y Período).
* Descripción física e historia detallada.
* Niveles de peligro dinámicos y etiquetas personalizadas.

### 📱 PWA Ready
Totalmente instalable en dispositivos móviles y de escritorio gracias a su soporte para **Service Workers** y manifiesto de aplicación.

---

## 🛠️ Stack Tecnológico

| Componente | Tecnologías |
| :--- | :--- |
| **Frontend** | HTML5, CSS3 (Variables dinámicas, Grid/Flexbox), JavaScript (ES6+) |
| **Base de Datos** | IndexedDB (Local) & GitHub Gist API (Cloud Sync) |
| **Gráficos** | HTML5 Canvas (Particle Engine) & Animaciones CSS3 |

---

## 🚀 Instalación y Uso

1.  Clona el repositorio.
2.  Abre `index.html` en tu navegador o levanta un servidor local.
3.  Configura tu **GitHub Token** y **Gist ID** en el panel de configuración ⚙️ para activar la sincronización.

---

**Desarrollado por [Brian Aguirre]** *Explorando los límites de la web y el horror cósmico.*
