# IUSM-connectivity-pipeline

## A NEW VERSION OF THIS REPOSITORY IS AVAILABLE AT: https://github.com/IUSCA/IUSM-ConnPipe
This repository will receive intermittent updates for bug fixes and matlab funtionality, but all major content and support updates will be carried out on the IUSM-ConnPipe repository.

## Contributors:
   * Evgeny Chumin, Indiana University School of Medicine, 2018
   * John West, Indiana University School of Medicine, 2018
   * Zikai Lin, Indiana University School of Medicine, 2018
   * Mario Dzemidzic, Indiana University School of Medicine, 2018
   * Joaquin Goni, Purdue University, 2018
   * Enrico Amico, Purdue University, 2018
     
## Description:
Executes pre-processing of anatomical, functional, and diffusion Magnetic Resonance Imaging data.

## Requirements:
This code has been developed to operate with the following software:
  * FSL version 5.0.10/11         https://fsl.fmrib.ox.ac.uk/fsl/fslwiki
  * AFNI                          https://afni.nimh.nih.gov/
  * dcm2niix (part of MRIcroGL)   https://github.com/rordenlab/dcm2niix
  * Camino                        http://camino.cs.ucl.ac.uk/
  * Camino-TrackVis               https://www.nitrc.org/projects/camino-trackvis/

## Usage:
Located within the 'template_batch_files' subdirectory are two matlab script files:

  * 'batch_setup.m'
  * 'system_and_sample_setup_local.m'
  
These files must be modified to contain approporiate paths for your software and data. They also contain extensive documentation on usage, directory structure set-up, software requirements, etc...
We recommend that these files are copied to a separate project directory, where they can be easily associated with your data.

Once modified, the 'run_connectivity_pipeline.m' function can be ran. Through the file selection user interface, select your modified files one at a time, after which processing will begin.

### Pertinent References:
under construction
