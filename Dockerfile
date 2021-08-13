FROM tensorflow/tensorflow:2.5.1-gpu-jupyter

WORKDIR /opt/colabfold

# Install python dependencies.
# TODO: should this go before conda installation???
RUN python -m pip install --no-cache-dir \
        biopython \
        dm-haiku \
        ml-collections \
        py3Dmol

# Download model.
RUN git clone https://github.com/deepmind/alphafold.git --quiet \
    && (cd alphafold; git checkout 0bab1bf84d9d887aba5cfb6d09af1e8c3ecbc408 --quiet) \
    && mv alphafold alphafold_ \
    && mv alphafold_/alphafold . \
    # remove "END" from PDBs, otherwise biopython complains
    && sed -i "s/pdb_lines.append('END')//" alphafold/common/protein.py \
    && sed -i "s/pdb_lines.append('ENDMDL')//" alphafold/common/protein.py

# Download model params.
RUN mkdir params \
    && curl -fsSL https://storage.googleapis.com/alphafold/alphafold_params_2021-07-14.tar \
    | tar x -C params \
    && touch AF2_READY

# Download libraries for interfacing with MMseq2 API.
RUN apt-get update \
    && apt-get install --no-install-recommends --yes \
        curl \
        gawk \
        jq \
        zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && touch MMSEQ2_READY

# Setup conda.
RUN curl -fsSLO https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash Miniconda3-latest-Linux-x86_64.sh -bfp /usr/local \
    && rm Miniconda3-latest-Linux-x86_64.sh \
    && touch CONDA_READY

# Setup template search.
RUN conda install --yes --quiet -c conda-forge -c bioconda \
        kalign3=3.2.2 \
        hhsuite=3.3.0 \
        python=3.7 \
    && conda clean --all --yes \
    && touch HH_READY

# Setup openmm for amber refinement.
RUN conda install --yes --quiet -c conda-forge \
        openmm=7.5.1 \
        python=3.7 \
        pdbfixer \
    && conda clean --all --yes \
    && (cd /usr/local/lib/python3.7/site-packages; patch -s -p0 < alphafold_/docker/openmm.patch) \
    && wget -qnc https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt \
    && mv stereo_chemical_props.txt alphafold/common/ \
    && touch AMBER_READY

# Copy over notebooks.
COPY . .

# Comment out google-drive-specific imports.
RUN sed -i 's/^from google.colab/# &/' *.ipynb

# TODO: Replace files.download with a jupyter-notebook equivalent...
# https://stackoverflow.com/questions/26497912/trigger-file-download-within-ipython-notebook
