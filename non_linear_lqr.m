clear;
addpath('./mr/')

% L1, L2: arm lengths
L1 = 0.5;
L2 = 0.5;
theta_min = 0.2;

robot = get2RRobot(L1, L2);

% start and goal positions for the end effector
qinit = [theta_min ; theta_min];

start = [L1*cos(theta_min) + L2*cos(theta_min) ...
        L1*sin(theta_min) + L2*sin(theta_min)];

target = [-0.5 0.8];
dt = 0.1;
Tf = 5;

st_tr = trvec2tform([start 0]);
target_tr = trvec2tform([target 0]);
traj = CartesianTrajectory(st_tr, target_tr, 5, 5/dt, 5);


A = eye(2);
B = @(theta1,theta2) [-L1*sin(theta1)-L2*sin(theta1+theta2) -L2*sin(theta1+theta2); ...
                    L1*cos(theta1)+L2*cos(theta1+theta2) L2*cos(theta1+theta2)]*dt;

Q = eye(2);
R = eye(2);

x = start';
y = x;
q = qinit;

xs = [];
us = [];
es = [];
qs = [];
for i=1:length(traj) + 5
    if i<length(traj)
        [~, x_bar] = TransToRp(traj{i});
    else
        [~, x_bar] = TransToRp(traj{end});
    end
    Bt = B(q(1), q(2));
    k = lqr(A, Bt, Q, R);
    
%     centralization
    x_bar = x_bar(1:2);
    x_hat = (y - x_bar);
    ut = -k*x_hat(1:2);
    
%     do forward kinematics
    xt = A*x + Bt*ut;  
    q = q + ut*dt;
    
    y = xt; %perfect full state observation 
    x = xt; %state
    
    % plotting data
    es = [es norm(xt-x_bar)];
    xs = [xs xt];
    us = [us ut];
    qs = [qs q];
    
end

% animate the robot

figure
f1 = show(robot,qs(:,1));
view(2)
ax = gca;
ax.Projection = 'orthographic';
hold on
framesPerSecond = 1/dt;
r = rateControl(framesPerSecond);

for i = 1:length(qs)
    f1 = show(robot,qs(:,i),'PreservePlot',false);
    h=findall(f1); %finding all objects in figure
    hlines=h.findobj('Type','Line'); %finding line object 
    %editing line object properties
    n=size(hlines);
    for j=1:2
        hlines(j).LineWidth = 3; %chanding line width
        hlines(j).Color=[1 0 0.5];%changing line color
        hlines(j).Marker='o';%changing marker type
        hlines(j).MarkerSize=5; %changing marker size
    end
    drawnow
    filename = 'added_noise1.gif';
    frame = getframe(1);
    im = frame2im(frame);
    [imind,cm] = rgb2ind(im,256);
    if i == 1 
      imwrite(imind,cm,filename,'gif', 'Loopcount',inf);
    else
      imwrite(imind,cm,filename,'gif','Writemode','append', 'DelayTime', dt);
    end
    waitfor(r);
end
hold off

% visualize the plots
fprintf('Total control: %d', norm(us));
t = (dt:dt:length(es)*dt);

figure
plot(t,es(1,:),'-r','LineWidth',2);
xlabel('Time (s)');
ylabel('Absolute error (m)');

figure
plot(t,xs(1,:),'-r',t,xs(2,:),'-g','LineWidth',2);
legend('X','Y');
xlabel('Time (s)');
ylabel('Displacement(m)');

