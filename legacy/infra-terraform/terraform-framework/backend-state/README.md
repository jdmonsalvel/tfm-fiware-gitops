**Overview**

Este script (`backend-create.sh`) prepara y gestiona el backend remoto para Terraform entre una cuenta "manager" (donde se crea el bucket S3 y la tabla DynamoDB) y una cuenta "managed" (donde se crea el role que permitirá a CICD operar).

**What It Does**
- **Crea/asegura un rol**: `manager-cicd-role` en la cuenta manager y `automate-cicd-role` en la cuenta managed (si no existen).
- **Crea/asegura un bucket S3** para almacenar el state (con versioning, cifrado y bloqueo de acceso público).
- **Crea/asegura una tabla DynamoDB** para el locking del state.
- **Genera** un archivo `backend.tf` local con la configuración del backend S3/DynamoDB.

**Prerequisitos**
- **AWS CLI** configurado con perfiles para la cuenta manager y la cuenta managed.
- Permisos para S3, DynamoDB e IAM en las cuentas correspondientes.
- Tener `bash` disponible (el script usa `set -euo pipefail`).

**Usage**
- Básico (setup / crear resources):

  ```bash
  ./backend-state/backend-create.sh <master-account-profile> <managed-account-profile> <managed-account.tfvars>
  ```

- Para ejecutar la ruta de destrucción (opcional):

  ```bash
  ./backend-state/backend-create.sh <master-account-profile> <managed-account-profile> <managed-account.tfvars> destroy
  ```

  - El script mostrará el mensaje:

    ```text
    You must run `terraform destroy` first to delete the state.
    Did you delete the state?
    Type 'yes' to confirm:
    ```

  - Solo si respondes exactamente `yes` ejecutará la eliminación de:
    - El archivo de state en S3 y todas sus versiones/delete-markers.
    - La tabla DynamoDB de locking.
    - El role `automate-cicd-role` en la cuenta managed (desvincula políticas y borra inline policies antes de eliminar el role).

**Probar con el sandbox (variables/template.tfvars)**
- El repositorio incluye `variables/template.tfvars` (plantilla). Para pruebas locales, copia o crea un fichero con los valores de sandbox (ej. `variables/sandbox.tfvars`) y pásalo como tercer argumento.

  Ejemplo (asumiendo que `variables/template.tfvars` ya contiene valores válidos para sandbox):

  ```bash
  cp variables/template.tfvars variables/sandbox.tfvars
  ./backend-state/backend-create.sh <master-profile> <managed-profile> variables/sandbox.tfvars
  ```

  - Para probar la eliminación con sandbox:

  ```bash
  ./backend-state/backend-create.sh <master-profile> <managed-profile> variables/sandbox.tfvars destroy
  # responder 'yes' cuando pregunte la confirmación
  ```

**Notas importantes y seguridad**
- El script realiza operaciones destructivas cuando se ejecuta con `destroy` y confirmas con `yes`.
- Asegúrate de ejecutar `terraform destroy` en el workspace correspondiente antes de pedir al script que borre el estado remoto.
- El borrado del objeto en S3 incluye eliminación de versiones; esto es irreversible salvo que tengas backups adicionales.
- El script no borra `manager-cicd-role` en la cuenta manager; sólo borra `automate-cicd-role` en la cuenta managed.

**Comandos útiles**
- Comprobar sintaxis del script:

  ```bash
  bash -n backend-state/backend-create.sh
  ```

- Probar los comandos AWS en modo dry-run: reemplaza llamadas reales por `echo aws ...` o ejecuta con credenciales limitadas en un entorno de pruebas.

**Troubleshooting**
- Si obtienes errores de permisos, verifica los perfiles AWS y que las políticas permitan `s3:*`, `dynamodb:*`, `iam:*`, y `sts:GetCallerIdentity` según la operación.
- Si el bucket S3 no existe y la creación falla, revisa que la `--region` pasada sea válida y que el perfil tenga permisos para crear buckets en esa región.

**Contacto / Next Steps**
- Si quieres, puedo añadir una bandera `--yes` para evitar la confirmación interactiva (no recomendado), o un modo `--dry-run` que imprima las acciones sin ejecutarlas.
