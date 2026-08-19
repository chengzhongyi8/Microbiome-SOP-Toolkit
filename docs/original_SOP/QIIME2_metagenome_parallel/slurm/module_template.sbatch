#!/usr/bin/env bash
#SBATCH --job-name=EDIT_ME
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x.%j.out
#SBATCH --error=logs/%x.%j.err

set -euo pipefail

# This is a template only. It is never submitted automatically.
# Edit environment activation, paths, resources, and exactly one module command.
PIPELINE_DIR="/path/to/Bioinformatics_Pipelines/metagenome"
source "${PIPELINE_DIR}/config/project_config.sh"
source "${PIPELINE_DIR}/config/databases.sh"
source "${PIPELINE_DIR}/config/activate_conda_env.sh" "${ENV_ASSEMBLY}" "${MEGAHIT}"
bash "${PIPELINE_DIR}/02_assembly/01_megahit_per_sample.sh"
