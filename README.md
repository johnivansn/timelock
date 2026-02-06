# ROADMAP REDUCIDO – APPTIMECONTROL (VERSIÓN REALISTA)

## ESTADO ACTUAL

**MVP Alpha + Beta features** ✅

* Tracking de apps
* Bloqueo por cuota diaria
* Bloqueo por WiFi
* Reset diario
* PIN admin
* Notificaciones
* Export / Import

---

## ALCANCE FINAL DEFINIDO ✅

👉 **Solo se implementarán los siguientes sprints**:

```
Sprint 11 – Correcciones críticas
Sprint 12 – UI Material Design 3
Sprint 18 – Bloqueo por horario
Sprint 19 – Quick actions y widget
Sprint 21 – Optimización técnica
```

❌ Todo lo demás (backups, logs, perfiles, recovery PIN, anti-bypass avanzado, accesibilidad completa) queda **fuera del alcance**.

---

## FASE 1 – CORRECCIONES CRÍTICAS (OBLIGATORIO)

### Sprint 11 — Detección Completa y Protección

**Duración**: 1–2 semanas

#### Objetivo

Que la app sea **confiable y difícil de evadir** en uso real.

#### Alcance final

1. **Detección completa de apps**

   * Incluir apps de usuario + apps del sistema actualizadas
   * Excluir solo apps core (Settings, System UI, etc.)
   * Lista consistente en todos los Android soportados

2. **Detección automática de WiFi**

   * Android 10+: detección dinámica
   * Versiones antiguas: redes guardadas
   * Red actual siempre visible
   * Historial simple de redes usadas

3. **Protección contra desinstalación**

   * DeviceAdminReceiver
   * Requiere desactivar admin antes de desinstalar
   * Advertencia clara al usuario

#### Device Owner (protección total)

La protección total contra desinstalación solo es posible si la app es **Device Owner**.

Pasos de aprovisionamiento con ADB (dispositivo recién reseteado o sin cuentas):

```text
adb shell dpm set-device-owner com.example.timelock/com.example.timelock.admin.DeviceAdminManager
```

Notas:

1. Esto requiere un dispositivo limpio (generalmente con factory reset).
2. Si el comando falla con “not allowed”, el dispositivo no está listo para aprovisionamiento.
3. Una vez Device Owner, la app puede bloquear su desinstalación.

#### Criterios de aceptación

* ✅ ≥95% de apps visibles
* ✅ WiFi actual siempre detectable
* ✅ No se puede desinstalar por accidente
* ✅ Sin crashes Android 10–13+

---

### Sprint 12 — UI Material Design 3

**Duración**: 1–2 semanas

#### Objetivo

UI **moderna, limpia y profesional**, sin agregar complejidad funcional.

#### Alcance final

* Tema Material You (Android 12+)
* Material Symbols
* Cards 16dp, grid 8dp
* Colores semánticos correctos
* Animaciones sutiles
* Responsive phone + tablet

#### Pantallas incluidas

* Lista principal
* PIN setup / verify
* Permissions
* Settings
* Export / Import
* Diálogos (App, WiFi, Time)

#### Criterios de aceptación

* ✅ Cumple MD3
* ✅ Contraste WCAG AA
* ✅ UI consistente
* ✅ Sin lag

---

## FASE 2 – CONTROL REAL DEL TIEMPO

### Sprint 18 — Bloqueo por Horario

**Duración**: 1–2 semanas

#### Objetivo

Evitar distracciones en **momentos clave**, no solo por tiempo total.

#### Funcionalidad

* Bloqueos por rangos horarios
* Días de la semana configurables
* Múltiples rangos por app
* Integrado con:

  * Cuota diaria
  * WiFi blocking

#### Notificaciones

* Aviso 5 min antes
* Aviso al bloquear
* Aviso al desbloquear

#### Criterios de aceptación

* ✅ Precisión ±1 minuto
* ✅ Funciona en background
* ✅ Compatible con otras reglas
* ✅ UX clara y simple

---

## FASE 3 – USABILIDAD RÁPIDA

### Sprint 19 — Quick Actions y Widget

**Duración**: 1 semana

#### Objetivo

Acceso rápido sin abrir la app.

#### Alcance final

1. **Widget Android**

   * Tamaño pequeño y mediano
   * Tiempo restante por app
   * Actualización inteligente

2. **Notificación persistente**

   * Colapsable
   * No intrusiva
   * Accesos rápidos

3. **Edición rápida**

   * Long-press en app
   * Acciones contextuales
   * Slider de cuota inline

#### Criterios de aceptación

* ✅ Widget estable
* ✅ Notificación no molesta
* ✅ UX fluida
* ✅ Sin impacto en batería

---

## FASE 4 – OPTIMIZACIÓN

### Sprint 21 — Optimizaciones Técnicas

**Duración**: 1 semana

#### Objetivo

App **ligera, rápida y estable** a largo plazo.

#### Alcance final

1. **Modo ahorro batería**

   * Reduce frecuencia de tracking
   * Mantiene bloqueos activos

2. **Cache inteligente**

   * Apps instaladas
   * Íconos
   * Redes WiFi

3. **Limpieza de datos**

   * Purga de uso antiguo
   * DB < 10MB
   * Sin pérdida funcional

#### Criterios de aceptación

* ✅ <2% batería diaria
* ✅ Lista apps <500ms
* ✅ DB compacta
* ✅ UI sin stutter

---

## ROADMAP FINAL RESUMIDO

### Sprints incluidos

```
Sprint 11 – Correcciones críticas
Sprint 12 – UI Material Design 3
Sprint 18 – Bloqueo por horario
Sprint 19 – Widget y quick actions
Sprint 21 – Optimización
```

### Timeline total

```
Duración estimada: 7–9 semanas
```

### Resultado final

🎯 **AppTimeControl v1.5**

* Sólida
* Difícil de evadir
* UI moderna
* Control real por tiempo + horario
* Excelente rendimiento

