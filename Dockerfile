FROM debian:buster-slim

WORKDIR /opt/colabfold

# Download libraries for interfacing with MMseq2 API.
RUN apt-get update \
    && apt-get install --yes \
        curl \
        gawk \
        git \
        hmmer \
        jq \
        libxml2 \
        wget \
        zip \
        zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && touch MMSEQ2_READY

# Setup conda.
ENV PATH="/opt/conda/bin:$PATH"
RUN curl -fsSLO https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash Miniconda3-latest-Linux-x86_64.sh -bfp /opt/conda \
    && rm Miniconda3-latest-Linux-x86_64.sh \
    && touch CONDA_READY \
    && conda config --add channels conda-forge \
    && conda config --set channel_priority strict \
    && conda install -n base --yes --quiet -c conda-forge \
        python=3.7 \
        notebook \
        ipywidgets \
    && conda clean --all --yes

# Setup template search.
RUN conda install --yes --quiet -c conda-forge -c bioconda \
        kalign3=3.2.2 \
        hhsuite=3.3.0 \
        openmm=7.5.1 \
        cudatoolkit=11.2 \
        # For binaries like ptxas.
        cudatoolkit-dev=11.2 \
        cudnn=8.2 \
        pdbfixer \
        notebook \
    && conda clean --all --yes \
    && touch HH_READY \
    && touch AMBER_READY

# Apply openmm patch.
RUN wget -qnc https://raw.githubusercontent.com/deepmind/alphafold/main/docker/openmm.patch \
    && (cd /opt/conda/lib/python3.7/site-packages; patch -s -p0 < /opt/colabfold/openmm.patch) \
    && rm openmm.patch \
    && wget -qnc https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt \
    && touch AMBER_READY

# Install Colabfold.
COPY . /opt/colabfold
RUN /opt/conda/bin/python -m pip install --no-cache-dir install \
        /opt/colabfold[alphafold] \
        https://storage.googleapis.com/jax-releases/cuda11/jaxlib-0.1.75+cuda11.cudnn82-cp37-none-manylinux2010_x86_64.whl

RUN chmod -R a+rx /opt/conda/pkgs/cuda-toolkit

WORKDIR /work
ENTRYPOINT ["jupyter-notebook", "--ip", "0.0.0.0", "--no-browser"]
