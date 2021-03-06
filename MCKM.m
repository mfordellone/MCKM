% ************************************************************************* %
%                                                                           %
%                   ** Multiple Correspondence K-Means **                   %
%                                                                           %
% ************************************************************************* %

% Authors: Mario Fordellone and Maurizio Vichi 2015
% Sapienza University of Rome
% mail: mario.fordellone@uniroma1.it / maurizio.vichi@unioroma1.it

% ************************************************************************* %

function [Urkm,Arkm, Yrkm,frkm,inrkm, Xs,varT,var1,var2] = MCKM(X, K, Q, varargin)

%[Uc,Ac, Yc, fc, inc, Xs, varT, var1, var2]=MCKM(X, K, Q, 'Stand', 'qual', 'Rndst', 500);
%
% model X = UYmA' + E
% 
% problem: min||X-UYmA'||^2
% 
% being ||X||^2 = ||X-UYmA'||^2 + ||UYmA'||^2
%
% equivalent problem
%
% problem maximize ||UYmA'||^2
% subject to
%
% U binary and row stochastic
% A Orthonormal A'A=IJ


%
% INPUT
% X (n X J) data matrix
% K number of classes of Unitis
% Q number of Factors 
%
% Optional parameters:
%
% 'Stats'    ->    Default value: 'on', print the statistics of the fit of the
%                  model.
%                  If 'off' Statistics are not printed (used for simulation
%                  studies)
% 'Stand'    ->    Default value 'on', standardize variables and therefore compute DFA 
%                  on the correlation matrix.
%                  If 'off' does not standardize variables and therefore
%                  compute DFA on the variance-covariance matrix
% 
% 'Rndst'    ->    an integer values indicating the intital random starts.
%                  Default '20' thus, repeat the anaysis 20 times and retain the
%                  best solution.
% 'MaxIter'  ->    an integer value indicationg the maximum number of
%                  iterations of the algorithm
%                  Default '100'.
% 'ConvToll' ->    an arbitrary samll values indicating the convergence
%                  tollerance of the algorithm, Default '1e-9'.

%
% OUTPUT
% Arkm  (J x Q)         loading matrix for dimensionality reduction
% Urkm  (n x k)         membership matrix for clustering objects
% Yrkm  (n x Q)         Factor scores 
%

% n = numenr of objects
% J = number of variables


% Set optional parameters
%
% Required parameters: X and K

% initialization
%
[n,J]=size(X);
VC=eye(Q);

% centrering matrix
Jc=eye(n)-(1./n)*ones(n);

if nargin < 2
   error('Too few inputs');
end

if ~isempty(X)
    if ~isnumeric(X)
        error('Invalid data matrix');
    end  
    if min(size(X)) == 1
    error(message('Disjoint Factor Analysis:NotEnoughData'));
end

else
    error('Empty input data matrix');
end

if ~isempty(Q)
    if isnumeric(K)
        if Q > J 
              error('The number of latent factors larger that the number of variables');
           end    
    elseif Q < 1 
              error('Invalid number of latent factors');
    end
else
    error('Empty input number of latent factors');
end

% Optional parameters   
pnames = {'Stats' 'Stand' 'Rndst' 'MaxIter' 'ConvToll'};
dflts =  { 'on'    'on'     10       100       1e-9 };
[Stats,Stand,Rndst,MaxIter,ConvToll] = internal.stats.parseArgs(pnames, dflts, varargin{:});


%if ~isempty(eid)
%    error(sprintf('Disjoint Factor Analysis; %s',eid), emsg);
%end


% Statistics %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~isempty(Stats)
    if ischar(Stats)
       StatsNames = {'off', 'on'};
       js = strcmpi(Stats,StatsNames);
           if sum(js) == 0
              error(['Invalid value for the ''Statistics'' parameter: '...
                     'choices are ''on'' or ''off''.']);
           end
       Stats = StatsNames{js}; 
    else  
        error(['Invalid value for the ''Statistics'' parameter: '...
               'choices are ''on'' or ''off''.']);
    end
else 
    error(['Invalid value for the ''Statistics'' parameter: '...
           'choices are ''on'' or ''off''.']);
end
% end statistics %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Standardization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~isempty(Stand)
    if ischar(Stand)
       StandNames = {'off', 'on', 'qual'};
       js = strcmpi(Stand,StandNames);
           if sum(js) == 0
              error(['Invalid value for the ''Standardization'' parameter: '...
                     'choices are ''on'' or ''off'' or ''qual''.']);
           end
       Stand = StandNames{js}; 
       switch Stand
           
       case 'off'
           Xs = Jc*X;            
       case 'on'
           Xs = zscore(X,1);          
       case 'qual'
           BB=[];
           for j=1:J
                g(j)=max(X(:,j));
                Ij=eye(g(j));
                Bj=Ij(X(:,j),:);
                BB=[BB Bj];
           end
           L = diag(BB'*ones(n,1)); 
           Xs = J^-0.5*BB*L^-0.5;
           Xs = Jc*Xs;            
       end
    else  
        error(['Invalid value for the ''standardization'' parameter: '...
               'choices are ''on'' or ''off'' or ''qual''.']);
    end
else 
    error(['Invalid value for the ''standardization'' parameter: '...
            'choices are ''on'' or ''off'' or ''qual''.']);
end
% end Standardization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Rndst %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~isempty(Rndst)  
    if isnumeric(Rndst)
       if (Rndst < 0) || (Rndst > 1000) 
       error('Rndst must be a value in the interval [0,1000]');
       end
    else
       error('Invalid Number of Random Starts');
    end
else
    error('Invalid Number of Random Starts')
end
% end Rndst %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% MAxIter %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~isempty(MaxIter)  
    if isnumeric(MaxIter)
       if (MaxIter < 0) || (MaxIter > 1000) 
       error('MaxIter must be a value in the interval [0,1000]');
       end
    else
       error('Invalid Number of Max Iterations');
    end
else
    error('Invalid Number of Max Iterations')
end
% end MaxIter %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% ConvToll %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~isempty(ConvToll)  
    if isnumeric(ConvToll)
       if (ConvToll < 0) || (ConvToll > 0.1) 
       error('ConvToll must be a value in the interval [0,0.1]');
       end
    else
       error('Invalid Convergence Tollerance');
    end
else
    error('Invalid Convergence Tollerance')
end
% end ConvToll %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


VC=eye(Q);

[n,J]=size(X);

% centring matrix
%Jm=eye(n)-(1/n)*ones(n);

% compute var-covar matrix 
%S=(1/n)*X'*Jm*X;

% Standardize data
%Xs=Jm*X*diag(diag(S))^-0.5;
%Xs=zscore(X,1);
st=sum(sum(Xs.^2));

un=ones(n,1);
uk=ones(K,1);
um=ones(Q,1);
JJ=[1:J]';
KK=[1:n]';
% Start the algorithm %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 

for loop=1:Rndst
    U=randPU(n,K);
    su=sum(U);
    Dsu=diag(su);
    Dsum1=diag(1./su);
    Xmean = Dsum1*U'*Xs;
    it=0;
    % update A
    XX=Xs'*U*Dsum1*U'*Xs;
    [A,L]=eigs(XX,Q);
    %[dL,idL]=sort(diag(L), 'descend');
    %L=diag(dL);
    %A=A(:,idL);
    %Q=find(diag(L)>=1);
    A=A(:,1:Q);
    Ymean = Xmean*A;
    Y=Xs*A;
    f0=trace(Ymean'*Dsu*Ymean)/st;
    KK=[1:K];
    UC=eye(K);
    %maxf=f0;
% iteration phase
    YmeanE = Xmean*A*A';
    fdif=2*eps;
    for it=1:MaxIter
      % given Ymean update U
        
        %for i2=1:1
        for i=1:n
            posmin=KK(U(i,:)==1);
            %mindif=sum((Xs(i,:)-YmeanE(1,:)).^2);
            mindif=sum((Y(i,:)-Ymean(posmin,:)).^2); %IF factorial k-means
            for j=1:K
                U(i,:)=UC(j,:);
                if sum(U(:,posmin))>0
                    su=sum(U);
                    %Dsu=diag(su);
                    %Ymean = diag(1./su)*U'*Xs*A;    
                    %f=trace(Ymean'*Dsu*Ymean)/st;
                    %dif=sum((Xs(i,:)-YmeanE(j,:)).^2);
                    dif=sum((Y(i,:)-Ymean(j,:)).^2);%IF factorial k-means
                    if dif < mindif
                        mindif=dif;
                        posmin=j;
                    end 
                else
                     %U(i,:)=UC(posmin,:);
                end
            end
            U(i,:)=UC(posmin,:);
        end
        %end
        
     %
        su=sum(U);
        % given U compute Xmean (compute centroids)
        Dsu=diag(su);
        Dsum1=diag(1./su);
        Xmean = Dsum1*U'*Xs;
     
        f1=trace((Xmean*A)'*Dsu*(Xmean*A))/st;
        % given U and Xmean update A
        XX=Xs'*U*Dsum1*U'*Xs;
        [A,L]=eigs(XX,Q);
        %[dL,idL]=sort(diag(L), 'descend');
        %L=diag(dL);
        %A=A(:,idL);
        %Q=find(diag(L)>=1);
        A=A(:,1:Q);
        Ymean = Xmean*A;

        Y=Xs*A;
        f=trace(Ymean'*Dsu*Ymean)/st;
        
        fdif = f-f0;
        
        if fdif > eps 
            f0=f; A0=A; 
        else
            break
        end
    end
  disp(sprintf('MCKM: Loop=%g, Explained variance=%g, iter=%g, fdif=%g',loop,f*100, it,fdif))   
       if loop==1
            Urkm=U;
            Arkm=A;
            Yrkm=Xs*Arkm;
            frkm=f;
            looprkm=1;
            inrkm=it;
            fdifo=fdif;
        end
   if f > frkm
       Urkm=U;
       frkm=f;
       Arkm=A;
       Yrkm=Xs*Arkm;
       looprkm=loop;
       inrkm=it;
       fdifo=fdif;
   end
end
% sort components in descend order of variance
% and rotate factors
%varYrkm=var(Yrkm,1);
%[c,ic]=sort(varYrkm, 'descend');
%Arkm=Arkm(:,ic);
%Yrkm=Yrkm(:,ic); 
Arkm=rotatefactors(Arkm, 'maxit', 500000);
% sort clusters of objects in descending order of cardinality
%dwc=zeros(K,1);
%for k=1:K
%dwc(k)= trace((Yrkm-Urkm*pinv(Urkm)*Yrkm)'*diag(Urkm(:,k))*(Yrkm-Urkm*pinv(Urkm)*Yrkm));
%end
%[c,ic]=sort(diag(Urkm'*Urkm), 'descend');
%Urkm=Urkm(:,ic);
disp(sprintf('MCKM (Final): Percentage Explained variance=%g, looprkm=%g, iter=%g, fdif=%g',frkm*100, looprkm, inrkm,fdifo))
%figure
%plotmatrix(Yrkm);

vlabs=cell(size(L,1),1);
col=cell(7);
col{1}='r';col{2}='g';col{3}='b';col{4}='c';col{5}='k';col{6}='m';col{7}='y';
vlb=cell(20);
vlb{1}='A';vlb{2}='B';vlb{3}='C';vlb{4}='D';vlb{5}='E';vlb{6}='F';vlb{7}='G';vlb{8}='H';vlb{9}='I';vlb{10}='L';
vlb{11}='M';vlb{12}='N';vlb{13}='P';vlb{14}='Q';vlb{15}='R';vlb{16}='S';vlb{17}='T';vlb{18}='U';vlb{19}='V';vlb{20}='Z';
ij=0;
for j=1:J
    for m=1:g(j)
        ij=ij+1;
        vlabs{ij}=strcat(vlb{j},num2str(m));
    end
end
    figure
    hold on
    axis square
    biplot(Arkm(:,1:2), 'scores',Yrkm(:,1:2), 'varlabels',vlabs);
    ax = gca;
    ax.XAxisLocation = 'origin';
    ax.YAxisLocation = 'origin';
    xlabel('Dimension 1');
    ylabel('Dimension 2');
    hold off

    figure
for c=1:K
    axis square
    ax = gca;
    ax.XAxisLocation = 'origin';
    ax.YAxisLocation = 'origin';
    plot(Yrkm((Urkm(:,c)==1),1), Yrkm((Urkm(:,c)==1),2), '.', 'MarkerSize',15)
    %scatter(Yrkm((Urkm(:,c)==1),1),Yrkm((Urkm(:,c)==1),2), s, col{k}, 'fill')

    box off
    hold on
end
    xlabel('Dimension 1');
    ylabel('Dimension 2');
    %leggend('Group 1', 'Group 2', 'Group 3', 'Group 4')
    hold off

var1=trace(Yrkm(:,1)'*Yrkm(:,1))./size(X,2);
var2=trace(Yrkm(:,2)'*Yrkm(:,2))./size(X,2);
varT=var1+var2;

%
% U matrix random generation
%

function [U]=randPU(n,c)

% generates a random partition of n objects in c classes
%
% n = number of objects
% c = number of classes
%
U=zeros(n,c);
U(1:c,:)=eye(c);

U(c+1:n,1)=1;
for i=c+1:n
    U(i,[1:c])=U(i,randperm(c));
end
U(:,:)=U(randperm(n),:);

%
% modified rand index (Hubert & Arabie 1985, JCGS p.198)
%

function mri=mrand(N)
n=sum(sum(N));
sumi=.5*(sum(sum(N').^2)-n);
sumj=.5*(sum(sum(N).^2)-n);
pb=sumi*sumj/(n*(n-1)/2);
mri=(.5*(sum(sum(N.^2))-n)-pb)/((sumi+sumj)/2-pb);
