FROM tensorflow/tensorflow:2.5.1-gpu-jupyter

WORKDIR /opt/colabfold

# Download libraries for interfacing with MMseq2 API.
RUN apt-get update \
    && apt-get install --yes \
        curl \
        gawk \
        jq \
        wget \
        zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && touch MMSEQ2_READY

# Setup conda.
ENV PATH="$PATH:/opt/conda/bin"
RUN curl -fsSLO https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash Miniconda3-latest-Linux-x86_64.sh -bfp /opt/conda \
    && rm Miniconda3-latest-Linux-x86_64.sh \
    && touch CONDA_READY

# Setup template search.
RUN conda install --yes --quiet -c conda-forge -c bioconda \
        kalign3=3.2.2 \
        hhsuite=3.3.0 \
        python=3.6 \
    && conda clean --all --yes \
    && touch HH_READY

# Setup openmm for amber refinement.
RUN conda install --yes --quiet -c conda-forge \
        openmm=7.5.1 \
        python=3.6 \
        pdbfixer \
    && conda clean --all --yes
# Apply openmm patch.
RUN wget -qnc https://raw.githubusercontent.com/deepmind/alphafold/main/docker/openmm.patch \
    && (cd /opt/conda/lib/python3.6/site-packages; patch -s -p0 < /opt/colabfold/openmm.patch) \
    && rm openmm.patch \
    && touch AMBER_READY

# Install python dependencies.
# Some of these dependencies were listed in the github repo deepmind/alphafold.
# Google colab includes some of these dependencies, like jax.
RUN python -m pip install --no-cache-dir -U pip \
    && python -m pip install --no-cache-dir \
        absl-py \
        biopython \
        chex \
        dm-haiku \
        dm-tree \
        immutabledict \
        ml-collections \
        py3Dmol \
        tqdm \
    && python -m pip install --no-cache-dir --upgrade \
        -f https://storage.googleapis.com/jax-releases/jax_releases.html \
        "jax[cuda111]" \
    # Fix tab-complete bug in jupyter-notebook.
    && python -m pip install --no-cache-dir \
        'jedi<0.18.0'

# Download system packages for advanced notebook.
RUN apt-get update \
    && apt-get install --yes \
        hmmer \
        zip \
    && rm -rf /var/lib/apt/lists/* \
    && touch MMSEQ2_READY

# Download model.
RUN git clone --quiet https://github.com/deepmind/alphafold.git alphafold-repo \
    && (cd alphafold-repo; git checkout 1e216f93f06aa04aa699562f504db1d02c3b704c --quiet) \
    && wget -q https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/colabfold.py \
    && wget -qnc https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/pairmsa.py \
    && wget -qnc https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/protein.patch \
    && wget -qnc https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/config.patch \
    && wget -qnc https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/model.patch \
    && wget -qnc https://raw.githubusercontent.com/sokrypton/ColabFold/main/beta/modules.patch \
    # Apply multi-chain patch from Lim Heo @huhlim
    && patch -u alphafold-repo/alphafold/common/protein.py -i protein.patch \
    # Apply patch to dynamically control number of recycles (idea from Ryan Kibler)
    && patch -u alphafold-repo/alphafold/model/model.py -i model.patch \
    && patch -u alphafold-repo/alphafold/model/modules.py -i modules.patch \
    && patch -u alphafold-repo/alphafold/model/config.py -i config.patch \
    # Install the local alphafold code.
    && python -m pip install --no-cache-dir --editable ./alphafold-repo \
    && mkdir -p alphafold-repo/common \
    && cd alphafold-repo/common/ \
    && wget -q https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt

# Download model params.
RUN mkdir -p alphafold-repo/data/params \
    && curl -fsSL https://storage.googleapis.com/alphafold/alphafold_params_2021-07-14.tar \
    | tar x -C alphafold-repo/data/params \
    && touch AF2_READY

WORKDIR /work
ENTRYPOINT ["jupyter-notebook", "--ip", "0.0.0.0", "--no-browser"]
