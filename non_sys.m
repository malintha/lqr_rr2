function dx = non_sys(x,x_bar,k)

%    centralization and calculate control
   y = x(1:2);
   x_hat = y-x_bar;
   u = -k*x_hat;
   
%    progress system
   theta1 = x(3);
   theta2 = x(4);
   L1 = 0.5;
   L2 = 0.5;
   A = eye(4);
   B = [-L1*sin(theta1)-L2*sin(theta1+theta2) -L2*sin(theta1+theta2); ...
       L1*cos(theta1)+L2*cos(theta1+theta2) L2*cos(theta1+theta2);
       1 0;
       0 1];
   dx = A*x + B*u;
end