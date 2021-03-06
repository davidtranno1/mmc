function node=readmmcnode(filename)
%
% node=readmmcnode(filename)
%
% Loading MMC node coordinates data file
%
% author: Qianqian Fang (fangq <at> nmr.mgh.harvard.edu)
%
% input:
%     filename: the file name to the node coordinate file
%
% output:
%     node: the surface triangle element list 
%
% example:
%     node=readmmcface('node_sph1.dat');
%
% this file is part of Mesh-based Monte Carlo (MMC)
%
% License: GPLv3, see http://mcx.sf.net/mmc/ for details
%

fid=fopen(filename,'rt');
hd=fscanf(fid,'%d',2);
node=fscanf(fid,'%d %e %e %e\n',hd(2)*4);
fclose(fid);

node=reshape(node,[4,hd(2)])';
node=node(:,2:4);
